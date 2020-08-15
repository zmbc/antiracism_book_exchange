class Copy < ApplicationRecord
  belongs_to :edition
  belongs_to :user
  belongs_to :book, through: :edition

  enum status: %i[available pending_waitlist_match pending_shipment shipping received lost]

  validates_presence_of :received_at, if: :received?
  validates_presence_of %i[tracker_id easypost_tracking_url],
                        if: -> { pending_shipment? || shipping? }
end
