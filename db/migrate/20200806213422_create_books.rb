class CreateBooks < ActiveRecord::Migration[6.0]
  def change
    create_table :books do |t|
      t.string :title, null: false
      t.string :author, null: false
      t.integer :year, null: false
      t.string :goodreads_url
      t.integer :copies_available, null: false
      t.integer :waitlist_length, null: false

      t.timestamps
    end
  end
end
