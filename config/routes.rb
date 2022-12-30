Rails.application.routes.draw do
  root 'sprite_stitcher#index'

  post '/stitch' => 'sprite_stitcher#stitch'
  get '/download' => 'sprite_stitcher#download'
end
