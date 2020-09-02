require 'test_helper'
require 'minitest/autorun'

class CopyTest < ActiveSupport::TestCase
  vcr_test 'successful reserve charges card and ships' do
    c = nil

    assert_difference('Shipment.count', 1) do
      assert_difference('Copy.where(status: :available).count', -1) do
        assert_no_difference('Copy.count') do
          c = Copy.reserve_and_ship_to_user!(books(:available), users(:one), 'pm_card_visa')
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
    assert_equal 0, pi.amount_capturable
    assert_equal 320, pi.amount_received
    assert_equal 'succeeded', pi.status
  end

  def self.test_card_does_nothing(card_name, pm_id, payment_error_code = nil)
    vcr_test "#{card_name} does nothing" do |start_time|
      assert_no_difference('Shipment.count') do
        assert_no_difference('Copy.where(status: :available).count') do
          assert_no_difference('Copy.count') do
            assert_raises(Stripe::CardError) do
              Copy.reserve_and_ship_to_user!(books(:available), users(:one), pm_id)
            end
          end
        end
      end

      assert_equal 0, EasyPost::Shipment.all(start_datetime: start_time.iso8601).shipments.count

      pis = Stripe::PaymentIntent.list(created: { gte: start_time.to_i })
      assert_equal 1, pis.count
      pi = pis.first
      assert_equal payment_error_code, pi.last_payment_error.code if payment_error_code.present?
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

  vcr_test 'invalid address does nothing' do |start_time|
    original_create = EasyPost::Address.method(:create)
    error = lambda { |options|
      raise EasyPost::Error if options[:name] == users(:invalid_address).full_name

      return original_create.call(options)
    }

    assert_difference('Shipment.count', 1) do
      assert_no_difference('Copy.where(status: :available).count') do
        assert_no_difference('Copy.count') do
          EasyPost::Address.stub(:create, error) do
            assert_raises(EasyPost::Error) do
              Copy.reserve_and_ship_to_user!(books(:available), users(:invalid_address), 'pm_card_visa')
            end
          end
        end
      end
    end

    s = Shipment.order(created_at: :desc).first
    assert_equal users(:available_owner), s.from_user
    assert_equal users(:invalid_address), s.to_user
    assert_equal :error, s.status.to_sym

    assert_equal 0, EasyPost::Shipment.all(start_datetime: start_time.iso8601).shipments.count

    pis = Stripe::PaymentIntent.list(created: { gte: start_time.to_i })
    assert_equal 1, pis.count
    pi = pis.first
    assert_equal 'canceled', pi.status
    assert_equal pi.id, s.stripe_payment_intent_id
  end

  vcr_test 'shipment buy failure does nothing' do |start_time|
    original_create = EasyPost::Shipment.method(:create)
    create_mock = lambda { |options|
      shipment = original_create.call(options)
      def shipment.buy(_)
        raise EasyPost::Error
      end
      return shipment
    }

    assert_difference('Shipment.count', 1) do
      assert_no_difference('Copy.where(status: :available).count') do
        assert_no_difference('Copy.count') do
          EasyPost::Shipment.stub(:create, create_mock) do
            assert_raises(EasyPost::Error) do
              Copy.reserve_and_ship_to_user!(books(:available), users(:one), 'pm_card_visa')
            end
          end
        end
      end
    end

    s = Shipment.order(created_at: :desc).first
    assert_equal users(:available_owner), s.from_user
    assert_equal users(:one), s.to_user
    assert_equal :error, s.status.to_sym

    assert_equal 0, EasyPost::Shipment.all(start_datetime: start_time.iso8601).shipments.count
    non_purchased = EasyPost::Shipment.all(purchased: false, start_datetime: start_time.iso8601).shipments
    non_purchased = non_purchased.filter { |eps| eps.to_address.name.upcase == users(:one).full_name.upcase }
    assert_equal 1, non_purchased.count
    assert_equal non_purchased.first.id, s.easypost_id

    pis = Stripe::PaymentIntent.list(created: { gte: start_time.to_i })
    assert_equal 1, pis.count
    pi = pis.first
    assert_equal 'canceled', pi.status
    assert_equal pi.id, s.stripe_payment_intent_id
  end

  vcr_test 'shipment database failure does nothing' do |start_time|
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

    assert_difference('Shipment.count', 1) do
      assert_no_difference('Copy.where(status: :available).count') do
        assert_no_difference('Copy.count') do
          Shipment.stub(:new, new_mock) do
            assert_raises(ActiveRecord::RecordInvalid) do
              Copy.reserve_and_ship_to_user!(books(:available), users(:one), 'pm_card_visa')
            end
          end
        end
      end
    end

    s = Shipment.order(created_at: :desc).first
    assert_equal users(:available_owner), s.from_user
    assert_equal users(:one), s.to_user
    assert_equal :error, s.status.to_sym

    purchased = EasyPost::Shipment.all(start_datetime: start_time.iso8601).shipments
    assert_equal 1, purchased.count
    purchased = purchased.first
    assert_equal purchased.id, s.easypost_id
    assert_equal 'submitted', purchased.refund_status

    pis = Stripe::PaymentIntent.list(created: { gte: start_time.to_i })
    assert_equal 1, pis.count
    pi = pis.first
    assert_equal 'canceled', pi.status
    assert_equal pi.id, s.stripe_payment_intent_id
  end

  vcr_test 'charge failure does nothing' do |start_time|
    error = proc { raise Stripe::CardError.new('No', 'Money!') }

    assert_difference('Shipment.count', 1) do
      assert_no_difference('Copy.where(status: :available).count') do
        assert_no_difference('Copy.count') do
          Stripe::PaymentIntent.stub(:capture, error) do
            assert_raises(Stripe::CardError) do
              Copy.reserve_and_ship_to_user!(books(:available), users(:one), 'pm_card_visa')
            end
          end
        end
      end
    end

    s = Shipment.order(created_at: :desc).first
    assert_equal users(:available_owner), s.from_user
    assert_equal users(:one), s.to_user
    assert_equal :error, s.status.to_sym

    purchased = EasyPost::Shipment.all(start_datetime: start_time.iso8601).shipments
    assert_equal 1, purchased.count
    purchased = purchased.first
    assert_equal purchased.id, s.easypost_id
    assert_equal 'submitted', purchased.refund_status

    pis = Stripe::PaymentIntent.list(created: { gte: start_time.to_i })
    assert_equal 1, pis.count
    pi = pis.first
    assert_equal 'canceled', pi.status
    assert_equal pi.id, s.stripe_payment_intent_id
  end
end
