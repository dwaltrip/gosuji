class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  helper_method :current_user

  private

  # return current_user, using existing object if available to save db hits
  def current_user
    begin
      @current_user ||= User.find(session[:user_id]) if session[:user_id]
    rescue ActiveRecord::RecordNotFound
      # this should only happen if user is deleted from User table, but user still has session cookies
      # or if somehow Rails session hash encryption is hacked, unlikely.
      # should log additional information here...
      logger.warn "-- current_user helper -- session hash contained invalid user_id!!"
      session.delete(:user_id)
      return nil
    end
  end

  def generate_token
    SecureRandom.urlsafe_base64(16)
  end

  def encrypt_data(data)
    encryptor.encrypt_and_sign(data)
  end

  def decrypt_data(encrypted_data)
    encryptor.decrypt_and_verify(encrypted_data)
  end

  def encryptor
    @encryptor ||= ActiveSupport::MessageEncryptor.new(Rails.application.config.secret_key_base)
  end

  def require_login
    unless current_user
      session[:login_redirect_url] = request.original_url
      redirect_to log_in_url, notice: "Please log in to perform this action."
    end
  end

end
