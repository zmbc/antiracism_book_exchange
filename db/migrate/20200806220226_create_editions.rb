class CreateEditions < ActiveRecord::Migration[6.0]
  def change
    create_table :editions do |t|
      t.belongs_to :book
      t.string :name
      t.decimal :width_inches, precision: 15, scale: 2
      t.decimal :length_inches, precision: 15, scale: 2
      t.decimal :height_inches, precision: 15, scale: 2
      t.decimal :weight_ounces, precision: 15, scale: 2
      t.timestamps
    end
  end
end
