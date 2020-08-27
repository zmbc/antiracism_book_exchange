class CreateWaitlistEntries < ActiveRecord::Migration[6.0]
  def change
    create_table :waitlist_entries do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.belongs_to :book, null: false, foreign_key: true
      t.datetime :notified_at

      t.timestamps
    end
  end
end
