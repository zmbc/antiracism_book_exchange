class CreateCopies < ActiveRecord::Migration[6.0]
  def change
    create_table :copies do |t|
      t.belongs_to :edition, null: false, foreign_key: true
      t.belongs_to :user, null: false, foreign_key: true
      t.integer :status, null: false
      t.string :tracker_id
      t.string :easypost_tracking_url
      t.datetime :received_at

      t.timestamps
    end
  end
end
