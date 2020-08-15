class CreateEditions < ActiveRecord::Migration[6.0]
  def change
    create_table :editions do |t|
      t.belongs_to :book, null: false
      t.string :name, null: false
      t.decimal :width_inches, precision: 15, scale: 2, null: false
      t.decimal :length_inches, precision: 15, scale: 2, null: false
      t.decimal :height_inches, precision: 15, scale: 2, null: false
      t.decimal :weight_ounces, precision: 15, scale: 2, null: false
      t.timestamps
    end
  end
end
