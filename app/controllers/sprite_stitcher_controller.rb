module StitchingAPI
  def convert_to_animations(images)
    images = images.transform_keys { |k| k[..k.rindex(".")] }

    animations = {}
    images.each do |k, v|
      frame_index_start = k.rindex(/\d/)
      return nil if frame_index_start.nil?

      animation = k[..(frame_index_start-1)]

      animations[animation] = [] if animations[animation].nil?
      animations[animation].append(
        {
          index: k[frame_index_start..].to_i,
          image: v
        }
      )
    end

    animations.transform_values! { |anim| anim.sort_by { |frame| frame[:index] } }
    animations
  end

  def create_spritesheet(token, sprite_dimensions, sprite_count)
    folder = tempfolder(token)
    path = "#{folder}/result.png"
    optimal_spritesheet_size = Math.sqrt(sprite_count).ceil
    MiniMagick::Tool::Convert.new do |img|
      img.format('png')
      img.size("#{sprite_dimensions[0] * optimal_spritesheet_size}x#{sprite_dimensions[1] * optimal_spritesheet_size}")
      img << "canvas:none"
      img << "-colorspace"
      img << "sRGB"
      img << path
    end
    return [optimal_spritesheet_size, optimal_spritesheet_size]
  end

  def compose_animations(token, sprite_dimensions, spritesheet_size, animations)
    folder = tempfolder(token)
    path = "#{folder}/result.png"

    result = MiniMagick::Image.open(path)
    result_json = {}

    x = 0
    y = 0

    # Blitting images and constructing json
    animations.each do |name, frames|
      result_json[name] = []
      frames.each do |frame|
        result = result.composite(frame[:image]) do |c|
          c.compose "Over" # OverCompositeOp
          c.geometry "+#{x * sprite_dimensions[0]}+#{y * sprite_dimensions[1]}"
          c << "-colorspace"
          c << "sRGB"
        end
        result_json[name].append([x, y])

        x += 1
        x = 0 and y += 1 if x >= spritesheet_size[0]
      end
    end

    # Add metadata to json
    result_json = {
      dimensions: sprite_dimensions,
      animations: result_json
    }

    # Save image
    result.write(path)

    # Save json
    File.open("#{folder}/result.json", "w") { |f| f << result_json.to_json }

    # Zip image and json together
    Zip::File.open("#{folder}/result.zip", Zip::File::CREATE) do |zip|
      zip.add("result.png", "#{folder}/result.png")
      zip.add("result.json", "#{folder}/result.json")
    end
  end

  def stitch_sprites(sprites)
    sprite_count = sprites.count
    return nil if sprite_count > 64

    any_sprite = nil
    sprites.transform_values! do |v|
      image = MiniMagick::Image.read(v)
      any_sprite = image if any_sprite.nil?
      image
    end
    return nil if any_sprite.nil?

    animations = convert_to_animations(sprites)
    sprite_dimensions = [any_sprite.width, any_sprite.height]

    token = SecureRandom.uuid
    spritesheet_dimensions = create_spritesheet(token, sprite_dimensions, sprite_count)
    compose_animations(token, sprite_dimensions, spritesheet_dimensions, animations)
    token
  end

  def tempfolder(token)
    Dir.mkdir("#{Dir.tmpdir}/sprite_stitcher") unless Dir.exist?("#{Dir.tmpdir}/sprite_stitcher")
    Dir.mkdir("#{Dir.tmpdir}/sprite_stitcher/#{token}") unless Dir.exist?("#{Dir.tmpdir}/sprite_stitcher/#{token}")
    "#{Dir.tmpdir}/sprite_stitcher/#{token}"
  end
end

class SpriteStitcherController < ApplicationController
  skip_before_action :verify_authenticity_token

  include StitchingAPI
  require "mini_magick"
  require "securerandom"
  require "json"
  require "zip"

  def index() end

  def stitch
    puts params
    sprites = stitch_params[:images]
    sprites.filter! { |i| i != "" && i.content_type == "image/png" }
    sprites.map! { |i| [i.original_filename, i.tempfile] }
    sprites = sprites.to_h

    render json: {
      token: stitch_sprites(sprites)
    }
  end

  def download
    folder = tempfolder(download_params)
    redirect_to root_path and return unless File.exist?("#{folder}/result.zip")

    send_file "#{folder}/result.zip", disposition: "attachment", filename: "result.zip"
  end

  private

  def stitch_params
    params.require(:stitch).permit!
  end

  def download_params
    params.require(:token)
  end
end
