class AddFieldsToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :full_name, :string, null: false
    add_column :users, :street, :string, null: false
    add_column :users, :street2, :string, null: false
    add_column :users, :city, :string, null: false
    add_column :users, :state, :string, null: false
    add_column :users, :postal_code, :string, null: false
    add_column :users, :admin, :boolean, null: false
  end
end
