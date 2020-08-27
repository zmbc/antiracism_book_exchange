class CreateShipments < ActiveRecord::Migration[6.0]
  def change
    create_table :shipments do |t|
      t.belongs_to :copy, null: false, foreign_key: true
      t.belongs_to :waitlist_entry, null: true, foreign_key: true
      t.references :from_user, null: false
      t.references :to_user, null: false
      t.foreign_key :users, column: :from_user_id
      t.foreign_key :users, column: :to_user_id
      t.integer :status, null: false
      t.string :easypost_id, null: false
      t.string :label_url, null: false
      t.string :easypost_tracker_id, null: false
      t.string :easypost_tracking_url, null: false
      t.string :stripe_payment_intent_id, null: false
      t.datetime :received_at
      t.boolean :sent_reminder_email

      t.timestamps
    end
  end
end
