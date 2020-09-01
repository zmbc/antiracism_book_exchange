ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

VCR.configure do |config|
  config.cassette_library_dir = 'vcr_cassettes'
  config.hook_into :webmock

  config.before_record do |i|
    i.request.headers.delete('Authorization')
  end

  # This shouldn't be needed as both seem to be in the Authorization header--but just in case :)
  config.filter_sensitive_data('<EASYPOST>') { Rails.application.credentials.config[:easypost_api_key] }
  config.filter_sensitive_data('<STRIPE>') { Rails.application.credentials.config[:stripe_secret_key] }
end

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  # parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...

  def self.vcr_test(name, &block)
    self.test(name) do
      VCR.use_cassette(name) do |cassette|
        Timecop.freeze(cassette.originally_recorded_at || Time.now) do
          instance_exec(Time.now, &block) # Time.now is according to Timecop
        end
      end
    end
  end

  def assert_same_address(easypost_address, user)
    assert_equal easypost_address.name.upcase, user.full_name.upcase
    assert_equal easypost_address.street1.upcase, user.street.upcase
    assert_equal easypost_address.street2.upcase, user.street2.upcase if user.street2.present?
    assert_equal easypost_address.city.upcase, user.city.upcase
    assert_equal easypost_address.state.upcase, user.state.upcase
  end
end
