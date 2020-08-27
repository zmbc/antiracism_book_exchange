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
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...

  def assert_same_address(easypost_address, user)
    assert_equal easypost_address.name, user.full_name
    assert_equal easypost_address.street1, user.street
    assert_equal easypost_address.street2, user.street2 if user.street2.present?
    assert_equal easypost_address.city, user.city
    assert_equal easypost_address.state, user.state
  end
end
