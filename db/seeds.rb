# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

Shipment.destroy_all
Copy.destroy_all
Edition.destroy_all
Book.destroy_all
User.destroy_all

admin = User.new(
  email: 'admin@antiracismbookexchange.com',
  admin: true,
  password: '123456',
  password_confirmation: '123456',
  full_name: 'Admin Admin',
  street: '777 Brockton Avenue',
  city: 'Abington',
  state: 'MA',
  postal_code: '02351'
)
admin.skip_confirmation!
admin.save!

rando = User.new(
  email: 'rando@antiracismbookexchange.com',
  admin: false,
  password: '123456',
  password_confirmation: '123456',
  full_name: 'Rando Rando',
  street: '30 Memorial Drive',
  city: 'Avon',
  state: 'MA',
  postal_code: '02322'
)
rando.skip_confirmation!
rando.save!

Book.create!(
  title: 'So You Want To Talk About Race',
  author: 'Ijeoma Oluo',
  year: 2018,
  goodreads_url: 'https://www.goodreads.com/book/show/35099718-so-you-want-to-talk-about-race',
  copies_available: 0,
  waitlist_length: 0,
  editions: [
    Edition.new(name: 'Paperback', width_inches: 5.8, length_inches: 8.4, height_inches: 0.9, weight_ounces: 8.0)
  ]
)

b2 = Book.create!(
  title: 'How to Be an Antiracist',
  author: 'Ibram X. Kendi',
  year: 2019,
  goodreads_url: 'https://www.goodreads.com/book/show/35099718-so-you-want-to-talk-about-race',
  copies_available: 1,
  waitlist_length: 0,
  editions: [
    Edition.new(name: 'Hardcover', width_inches: 5.8, length_inches: 8.6, height_inches: 1.1, weight_ounces: 15.2)
  ]
)

Copy.create!(
  edition: b2.editions.first,
  user: rando,
  status: :available
)

Copy.create!(
  edition: b2.editions.first,
  user: rando,
  status: :available
)

Copy.create!(
  edition: b2.editions.first,
  user: rando,
  status: :available
)
