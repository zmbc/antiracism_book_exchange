require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AntiracismBookExchange
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    config.stripe.secret_key = Rails.application.credentials.config[:stripe_secret_key]
    config.stripe.publishable_key = 'pk_test_51HKYq9DdxaJLlE0xyX39d1MXO1h60juoPwf5ZbvoTxsYGPALVAmXQ3dvPPhIJN554Ah4oVrTdQgiheNQRUDMDLlg00TeUcnraa'
  end
end
