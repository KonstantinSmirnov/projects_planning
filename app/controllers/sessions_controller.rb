class SessionsController < ApplicationController
  skip_before_action :require_authentication

  # Single hardcoded admin account — there's no registration or user table.
  ADMIN_EMAIL = "admin@admin.com"
  ADMIN_PASSWORD = "amway123"

  def new
  end

  def create
    if authorized?(params[:email], params[:password])
      reset_session
      session[:authenticated] = true
      redirect_to root_path, notice: "Signed in."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Signed out."
  end

  private

  # Digest both sides first so secure_compare always sees equal-length
  # strings (it isn't safe to feed it attacker-controlled lengths directly).
  def authorized?(email, password)
    secure_compare_digest(email, ADMIN_EMAIL) & secure_compare_digest(password, ADMIN_PASSWORD)
  end

  def secure_compare_digest(input, expected)
    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(input.to_s), Digest::SHA256.hexdigest(expected)
    )
  end
end
