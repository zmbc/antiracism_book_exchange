class CreateBooks < ActiveRecord::Migration[6.0]
  def change
    create_table :books do |t|
      t.string :title
      t.string :author
      t.integer :year
      t.string :goodreads_url
      t.integer :copies_available
      t.integer :waitlist_length

      t.timestamps
    end
  end
end
