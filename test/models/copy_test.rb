require 'test_helper'
require 'minitest/autorun'

class CopyTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  vcr_test 'successful reserve puts hold on card and ships' do
    c = nil

    assert_emails 2 do
      assert_difference('Shipment.count', 1) do
        assert_difference('Copy.where(status: :available).count', -1) do
          assert_no_difference('Copy.count') do
            c = Copy.reserve_and_ship_to_user!(books(:available), users(:one), 'pm_card_visa')
          end
        end
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
    assert_equal 320, pi.amount_capturable
    assert_equal 0, pi.amount_received
    assert_equal 'requires_capture', pi.status
  end

  def assert_does_nothing(
    error_class:,
    payment_method: 'pm_card_visa',
    payment_error_code: nil,
    db_shipment_saved_error: false,
    stripe_status: 'canceled'
  )
    assert_no_emails do
      assert_difference('Shipment.count', db_shipment_saved_error ? 1 : 0) do
        assert_no_difference('Copy.where(status: :available).count') do
          assert_no_difference('Copy.count') do
            assert_raises(error_class) do
              Copy.reserve_and_ship_to_user!(books(:available), users(:one), payment_method)
            end
          end
        end
      end
    end

    s = nil
    if db_shipment_saved_error
      s = Shipment.order(created_at: :desc).first
      assert_equal users(:available_owner), s.from_user
      assert_equal users(:one), s.to_user
      assert_equal :error, s.status.to_sym
    end

    purchased_shipments = EasyPost::Shipment.all(start_datetime: Time.now.iso8601).shipments
    non_refunded_shipments = purchased_shipments.filter { |eps| eps.refund_status != 'submitted' }
    assert_equal 0, non_refunded_shipments.count

    pis = Stripe::PaymentIntent.list(created: { gte: Time.now.to_i })
    assert_equal 1, pis.count
    pi = pis.first
    assert_equal payment_error_code, pi.last_payment_error.code if payment_error_code.present?
    assert_equal stripe_status, pi.status
    assert_equal pi.id, s.stripe_payment_intent_id if db_shipment_saved_error
  end

  def self.test_card_does_nothing(card_name, pm_id, payment_error_code = nil)
    vcr_test "#{card_name} does nothing" do
      assert_does_nothing(
        error_class: Stripe::CardError,
        payment_method: pm_id,
        payment_error_code: payment_error_code,
        stripe_status: 'requires_payment_method'
      )
    end
  end

  test_card_does_nothing(
    'card that needs two-step authentication',
    'pm_card_authenticationRequired',
    'authentication_required'
  )

  test_card_does_nothing(
    'card declined',
    'pm_card_chargeDeclined',
    'card_declined'
  )

  test_card_does_nothing(
    'card with insufficient funds',
    'pm_card_chargeDeclinedInsufficientFunds',
    'card_declined'
  )

  test_card_does_nothing(
    'fraudulent card',
    'pm_card_chargeDeclinedFraudulent',
    'card_declined'
  )

  test_card_does_nothing(
    'card with incorrect CVC',
    'pm_card_chargeDeclinedIncorrectCvc',
    'incorrect_cvc'
  )

  test_card_does_nothing(
    'expired card',
    'pm_card_chargeDeclinedExpiredCard',
    'expired_card'
  )

  test_card_does_nothing(
    'card with processing error',
    'pm_card_chargeDeclinedProcessingError',
    'processing_error'
  )

  vcr_test 'invalid address does nothing' do
    original_create = EasyPost::Address.method(:create)
    error = lambda { |options|
      raise EasyPost::Error if options[:name] == users(:one).full_name

      return original_create.call(options)
    }

    EasyPost::Address.stub(:create, error) do
      assert_does_nothing(
        error_class: EasyPost::Error,
        db_shipment_saved_error: true
      )
    end
  end

  vcr_test 'shipment buy failure does nothing' do
    original_create = EasyPost::Shipment.method(:create)
    create_mock = lambda { |options|
      shipment = original_create.call(options)
      def shipment.buy(_)
        raise EasyPost::Error
      end
      return shipment
    }

    EasyPost::Shipment.stub(:create, create_mock) do
      assert_does_nothing(
        error_class: EasyPost::Error,
        db_shipment_saved_error: true
      )
    end
  end

  vcr_test 'shipment database failure does nothing' do
    original_new = Shipment.method(:new)
    new_mock = lambda { |options|
      shipment = original_new.call(options)
      class << shipment
        define_method(:save!, proc {
          raise ActiveRecord::RecordInvalid if status.to_sym != :error

          super()
        })
      end
      return shipment
    }

    Shipment.stub(:new, new_mock) do
      assert_does_nothing(
        error_class: ActiveRecord::RecordInvalid,
        db_shipment_saved_error: true
      )
    end
  end
end
