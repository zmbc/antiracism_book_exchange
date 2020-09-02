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
    # Error handling is pretty tricky here. We need to make actions across multiple
    # APIs atomic--or as atomic as possible. The thing we want to *really* avoid
    # is having to refund someone's card. So we do that last. However, we place
    # a "hold"/pre-authorization on the card before we buy the shipment, because
    # we'd rather not be buying shipments left and right when people are making
    # typos on their card number. The authorization creates a *virtual*
    # guarantee that the charge will succeed, but it's not 100%. Apparently,
    # refunding on EasyPost can often fail if it's done too quickly--we could
    # create a cron job to make sure errored shipments get refunded, or just do
    # them manually when we see it in Honeybadger.
    intent = create_card_hold!(payment_method_id)

    s = new_shipment_to(to_user)
    s.stripe_payment_intent_id = intent.id

    begin
      easypost_shipment = s.buy_easypost_shipment!
      s.save!

      capture_funds!(intent, ModelUtils.easypost_rate_to_total_price_cents(easypost_shipment.selected_rate))
    rescue StandardError
      rollback_external_changes!(intent, easypost_shipment)

      s.status = :error
      s.save!
      raise
    end
  end

  protected

  def create_card_hold!(payment_method_id)
    Stripe::PaymentIntent.create({
      amount: ModelUtils.easypost_rate_to_total_price_cents(create_dummy_easypost_shipment.lowest_rate),
      currency: 'usd',
      payment_method: payment_method_id,
      # Really confusing -- confirm: true does not actually charge the card.
      # It only confirms the hold.
      confirm: true,
      error_on_requires_action: true,
      capture_method: 'manual'
    })
  end

  def create_dummy_easypost_shipment
    address = User.first.create_easypost_address
    EasyPost::Shipment.create(
      to_address: address,
      from_address: address,
      parcel: edition.create_easypost_parcel,
      options: { special_rates_eligibility: 'USPS.MEDIAMAIL' }
    )
  end

  def capture_funds!(intent, amount)
    Stripe::PaymentIntent.capture(
      intent.id,
      {
        amount_to_capture: amount
      }
    )
  end

  def rollback_external_changes!(intent, easypost_shipment)
    Stripe::PaymentIntent.cancel(intent.id)
    # Undo/refund shipment on Easypost -- note that this may fail. If it
    # does, at least in Honeybadger it will be very clear what we need to
    # do.
    if easypost_shipment.present?
      begin
        easypost_shipment.refund
      rescue EasyPost::Error => e
        Honeybadger.notify(e)
        # Don't re-raise so we can continue with any more rollback logic
      end
    end
  end

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
