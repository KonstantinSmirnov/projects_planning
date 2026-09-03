class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # An empty form submission shouldn't dump a 400 error page on the user.
  rescue_from ActionController::ParameterMissing do
    redirect_to root_path, alert: "Nothing was submitted — fill the form in and try again."
  end

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to root_path, alert: "That item no longer exists."
  end
end
