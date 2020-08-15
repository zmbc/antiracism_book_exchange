class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from CanCan::AccessDenied do
    store_location_for :user, request.path
    redirect_to new_user_session_path, notice: 'You need to sign in first.'
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up) do |u|
      u.permit(:full_name, :email, :password, :password_confirmation, :street, :street2, :city, :state, :postal_code)
    end

    devise_parameter_sanitizer.permit(:account_update) do |u|
      u.permit(:full_name, :email, :password, :current_password, :street, :street2, :city, :state, :postal_code)
    end
  end

  def after_sign_in_path
    stored_location_for(:user) || books_path
  end

  def after_sign_up_path
    stored_location_for(:user) || books_path
  end
end
