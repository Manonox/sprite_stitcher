class CreateStitchRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :stitch_requests do |t|

      t.timestamps
    end
  end
end
