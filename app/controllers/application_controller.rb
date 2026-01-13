class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    # Permit additional parameters for sign up
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username])

    # Permit additional parameters for account update
    devise_parameter_sanitizer.permit(:account_update, keys: [:username])
  end
end
