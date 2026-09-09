ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  # Every controller requires authentication now, so integration tests need
  # a signed-in session before exercising the app's actual routes. Tests
  # that exercise the login/logout flow itself opt out with `self.skip_login_setup = true`.
  class_attribute :skip_login_setup, default: false

  setup do
    unless skip_login_setup
      post login_path, params: { email: SessionsController::ADMIN_EMAIL, password: SessionsController::ADMIN_PASSWORD }
    end
  end
end
