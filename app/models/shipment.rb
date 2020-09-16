class Shipment < ApplicationRecord
  belongs_to :copy
  belongs_to :from_user, class_name: 'User', foreign_key: :from_user_id
  belongs_to :to_user, class_name: 'User', foreign_key: :to_user_id

  enum status: %i[
    pending
    did_not_ship
    shipping
    received
    lost
    error
  ]

  validates_presence_of :received_at, if: :received?
  validates_presence_of %i[
    easypost_id
    label_url
    easypost_tracker_id
    easypost_tracking_url
    stripe_payment_intent_id
  ], unless: :error?

  def initiate(payment_method_id)
    # Error handling is pretty tricky here. We need to make actions across multiple
    # APIs atomic--or as atomic as possible. The authorization creates a *virtual*
    # guarantee that the charge (later) will succeed, but it's not 100%. Apparently,
    # refunding on EasyPost can often fail if it's done too quickly--we could
    # create a cron job to make sure errored shipments get refunded, or just do
    # them manually when we see it in Honeybadger.
    create_card_hold!(payment_method_id)

    status_error_on_failure do
      buy_easypost_shipment!
      save!
      send_pending_emails
    rescue StandardError
      rollback_external_changes!
      raise
    end
  end

  def confirm_shipped
    update! status: :shipping

    status_error_on_failure do
      charge_card!
      send_shipping_emails
    end
  end

  def confirm_did_not_ship
    update! status: :did_not_ship

    status_error_on_failure do
      copy.update! status: :failed
      rollback_external_changes!
      send_did_not_ship_emails
    end
  end

  protected

  def status_error_on_failure
    yield
  rescue StandardError
    self.status = :error
    save!
    raise
  end

  def send_pending_emails
    mailer.pending_email_to_sender.deliver_later
    mailer.pending_email_to_receiver.deliver_later
  end

  def send_shipping_emails
    mailer.shipping_email_to_sender.deliver_later
    mailer.shipping_email_to_receiver.deliver_later
  end

  def send_did_not_ship_emails
    mailer.did_not_ship_email_to_sender.deliver_later
    mailer.did_not_ship_email_to_receiver.deliver_later
  end

  def mailer
    ShipmentMailer.with(shipment: self)
  end

  def create_card_hold!(payment_method_id)
    intent = Stripe::PaymentIntent.create({
      amount: ModelUtils.easypost_rate_to_total_price_cents(create_dummy_easypost_shipment.lowest_rate),
      currency: 'usd',
      payment_method: payment_method_id,
      # Really confusing -- confirm: true does not actually charge the card.
      # It only "confirms" the hold.
      confirm: true,
      error_on_requires_action: true,
      capture_method: 'manual'
    })

    self.stripe_payment_intent_id = intent.id

    intent
  end

  def charge_card!
    Stripe::PaymentIntent.capture(stripe_payment_intent_id)
  end

  def create_dummy_easypost_shipment
    address = User.first.create_easypost_address
    EasyPost::Shipment.create(
      to_address: address,
      from_address: address,
      parcel: copy.edition.create_easypost_parcel,
      options: { special_rates_eligibility: 'USPS.MEDIAMAIL' }
    )
  end

  def rollback_external_changes!
    Stripe::PaymentIntent.cancel(stripe_payment_intent_id)
    # Undo/refund shipment on Easypost -- note that this may fail. If it
    # does, at least in Honeybadger it will be very clear what we need to
    # do.
    begin
      easypost_shipment.refund if easypost_shipment.present? &&
                                  easypost_shipment.selected_rate.present?
    rescue EasyPost::Error => e
      Honeybadger.notify(e)
      # Don't re-raise so we can continue with any more rollback logic
    end
  end

  def buy_easypost_shipment!
    create_easypost_shipment unless easypost_shipment.present?

    easypost_shipment.buy(rate: easypost_shipment.lowest_rate)
    label = easypost_shipment.label(file_format: 'PDF').postage_label

    self.label_url = label.label_pdf_url
    self.easypost_tracker_id = easypost_shipment.tracker.id
    self.easypost_tracking_url = easypost_shipment.tracker.public_url
  end

  def create_easypost_shipment
    eps = EasyPost::Shipment.create(
      to_address: to_user.create_easypost_address,
      from_address: from_user.create_easypost_address,
      parcel: copy.edition.create_easypost_parcel,
      options: { special_rates_eligibility: 'USPS.MEDIAMAIL' }
    )

    self.easypost_shipment = eps
  end

  def easypost_shipment
    @easypost_shipment ||=
      easypost_id.present? ? EasyPost::Shipment.retrieve(easypost_id) : nil
  end

  def easypost_shipment=(shipment)
    self.easypost_id = shipment.id
    @easypost_shipment = shipment
  end
end
