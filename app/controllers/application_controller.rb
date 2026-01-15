class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def configure_permitted_parameters
    # Permit additional parameters for sign up
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username])

    # Permit additional parameters for account update
    devise_parameter_sanitizer.permit(:account_update, keys: [:username])
  end

  private

  def user_not_authorized(exception)
    # Extract the action name from the exception query method
    # e.g., "index?" becomes :index
    action = exception.query.to_s.gsub('?', '').to_sym if exception.query

    # Get the policy instance and custom message
    policy = exception.policy
    if policy && policy.respond_to?(:authorization_message)
      flash[:alert] = policy.authorization_message(action)
    else
      flash[:alert] = "You are not authorized to perform this action."
    end

    redirect_to(request.referrer || root_path)
  end
end
