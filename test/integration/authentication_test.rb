require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  # These tests need to control the session state themselves, so opt out of
  # the base class's auto-login setup.
  self.skip_login_setup = true

  test "signed-out visitor is redirected to login" do
    get root_path
    assert_redirected_to login_path
  end

  test "correct credentials sign the admin in" do
    post login_path, params: { email: SessionsController::ADMIN_EMAIL, password: SessionsController::ADMIN_PASSWORD }
    assert_redirected_to root_path

    get root_path
    assert_response :success
  end

  test "wrong password is rejected" do
    post login_path, params: { email: SessionsController::ADMIN_EMAIL, password: "wrong" }
    assert_response :unprocessable_entity

    get root_path
    assert_redirected_to login_path
  end

  test "logout clears the session" do
    post login_path, params: { email: SessionsController::ADMIN_EMAIL, password: SessionsController::ADMIN_PASSWORD }
    delete logout_path
    assert_redirected_to login_path

    get root_path
    assert_redirected_to login_path
  end

  test "logout link is available in the nav" do
    post login_path, params: { email: SessionsController::ADMIN_EMAIL, password: SessionsController::ADMIN_PASSWORD }
    get root_path

    assert_select "form[action=?] button[type=submit]", logout_path, "Logout"
  end
end
