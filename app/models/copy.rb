class Copy < ApplicationRecord
  belongs_to :edition
  belongs_to :user
  has_one :book, through: :edition
  has_many :shipments

  enum status: %i[
    available
    pending_waitlist_match
    pending_waitlist_confirm
    reserved
  ]

  validates_presence_of :waitlist_entry, if: :pending_waitlist_confirm?

  after_commit :update_book_availability, if: :saved_change_to_status?

  def self.reserve_and_ship_to_user!(book, user, payment_method_id)
    c = reserve_available(book)

    begin
      c.ship_to_user!(user, payment_method_id)
    rescue StandardError
      # If anything goes wrong, reset the copy to be available again.
      c.status = :available
      c.save!
      raise
    end

    c
  end

  def self.reserve_available(book)
    # Locking ensures that nobody else is reserving the same copy concurrently.
    c = joins(:edition).lock.find_by!(status: :available, editions: { book_id: book.id })
    c.status = :reserved
    c.save! # Releases lock
    c
  end

  def ship_to_user!(to_user, payment_method_id)
    new_shipment_to(to_user).initiate(payment_method_id)
  end

  protected

  def new_shipment_to(to_user)
    Shipment.new(
      copy: self,
      from_user: user,
      to_user: to_user,
      status: :pending
    )
  end

  def update_book_availability
    book.recalculate_copies_and_waitlist
  end
end
