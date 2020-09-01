class Shipment < ApplicationRecord
  belongs_to :copy
  belongs_to :from_user, class_name: 'User', foreign_key: :from_user_id
  belongs_to :to_user, class_name: 'User', foreign_key: :to_user_id

  enum status: %i[
    pending
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

  def create_easypost_shipment
    EasyPost::Shipment.create(
      to_address: to_user.create_easypost_address,
      from_address: from_user.create_easypost_address,
      parcel: copy.edition.create_easypost_parcel,
      options: { special_rates_eligibility: 'USPS.MEDIAMAIL' }
    )
  end

  def buy_easypost_shipment!(easypost_shipment: nil)
    easypost_shipment ||= create_easypost_shipment

    easypost_shipment.buy(rate: easypost_shipment.lowest_rate)
    label = easypost_shipment.label(file_format: 'PDF').postage_label

    self.easypost_id = easypost_shipment.id
    self.label_url = label.label_pdf_url
    self.easypost_tracker_id = easypost_shipment.tracker.id
    self.easypost_tracking_url = easypost_shipment.tracker.public_url

    easypost_shipment
  end
end
