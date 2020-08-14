class User < ApplicationRecord
  # Others available are: :lockable, :timeoutable, and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable

  validates_address fields: %i[street street2 city state postal_code]

  validates_presence_of %i[full_name street city state postal_code] # Note: street2 not required!
end
