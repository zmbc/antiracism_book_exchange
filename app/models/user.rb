class User < ApplicationRecord
  # Others available are: :lockable, :timeoutable, and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable

  validates_address fields: %i[street street2 city state postal_code]
  validates :postal_code, length: { is: 5 }

  validates_presence_of %i[full_name street city state postal_code] # Note: street2 not required!

  def create_easypost_address
    EasyPost::Address.create(
      name: full_name,
      street1: street,
      street2: street2,
      city: city,
      state: state,
      zip: postal_code,
      country: 'US',
      verify_strict: ['delivery']
    )
  end
end
