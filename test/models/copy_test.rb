require 'test_helper'

class CopyTest < ActiveSupport::TestCase
  test 'successful reserve charges card and ships' do
    VCR.use_cassette('successful') do
      c = nil

      assert_difference('Shipment.count', 1) do
        assert_difference('Copy.where(status: :available).count', -1) do
          c = Copy.reserve_and_ship_to_user!(books(:available), users(:one), 'pm_card_visa')
        end
      end

      assert_equal :reserved, c.status.to_sym
      assert_equal 1, c.shipments.count
      s = c.shipments.first
      assert_equal users(:available_owner), s.from_user
      assert_equal users(:one), s.to_user

      ep_shipment = EasyPost::Shipment.retrieve(s.easypost_id)
      assert_same_address ep_shipment.from_address, users(:available_owner)
      assert_same_address ep_shipment.to_address, users(:one)
      assert_equal '2.80', ep_shipment.selected_rate.rate

      pi = Stripe::PaymentIntent.retrieve(s.stripe_payment_intent_id)
      assert_equal 320, pi.amount
      assert_equal 0, pi.amount_capturable
      assert_equal 320, pi.amount_received
      assert_equal 'succeeded', pi.status
    end
  end
end
