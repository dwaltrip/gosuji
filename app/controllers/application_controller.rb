class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  helper_method :current_user

  def redirect_bad_urls
    flash.alert = "The page #{request.original_fullpath.inspect} does not exist, or has been moved."
    redirect_to games_path
  end

  private

  def current_user
    begin
      @current_user ||= User.find(session[:user_id]) if session[:user_id]
    rescue ActiveRecord::RecordNotFound
      # this should only happen if user is deleted from User table, but user's browser still has session cookies
      logger.warn "-- current_user helper -- session hash contained invalid user_id"
      session.delete(:user_id)
      return nil
    end
  end

  def generate_token
    SecureRandom.urlsafe_base64(16)
  end

  def encrypt(data)
    encryptor.encrypt_and_sign(data)
  end

  def decrypt(encrypted_data)
    begin
      encryptor.decrypt_and_verify(encrypted_data)
    rescue => e
      sep = "========"
      logger.warn [sep, "decrypt_data failed!", "Error:", e.message, "Backtrace:", e.backtrace, sep].join("\n")
      return nil
    end
  end

  def encryptor
    @encryptor ||= ActiveSupport::MessageEncryptor.new(Rails.application.config.secret_key_base)
  end

  def require_login
    unless current_user
      session[:login_alert] = "Please log in to perform this action."
      session.delete(:login_redirect_url)

      if request.xhr?
        respond_to { |format| format.json { render json: { login_url: log_in_path }.to_json } }
      else
        session[:login_redirect_url] = request.original_url unless request.post?
        redirect_to log_in_url
      end
    end
  end
end
