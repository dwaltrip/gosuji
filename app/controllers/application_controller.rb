class ApplicationController < ActionController::Base
  around_filter :global_request_logging
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  helper_method :current_user, :tile_pixel_size

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

  def require_login
    unless current_user
      session[:login_redirect_url] = request.original_url
      redirect_to log_in_url, notice: "Please log in to perform this action."
    end
  end


  def global_request_logging
    verbose = false

    http_request_headers = {}
    if verbose
      logger.info "** Received #{request.method.inspect} to #{request.url.inspect} from #{request.remote_ip.inspect}"
      logger.info "** Processing with headers:"

      request.headers.each do |header_name, header_value|
        if header_name.match("^HTTP.*")
          http_request_headers[header_name] = header_value
          logger.info "-- #{header_name.inspect} => #{header_value.inspect}"
        end
      end

      logger.info "** Params:"
      params.each do |param_name, value|
        logger.info "**-- #{param_name.inspect} => #{value.inspect}"
      end
    else
      user_agent_hash = Digest::MD5.hexdigest(request.headers["HTTP_USER_AGENT"])
      logger.info "**** hash of USER_AGENT (unique identifier) = #{user_agent_hash.inspect}"
    end

    begin
      yield
    ensure
      if verbose
        logger.info "**** Responding with #{response.status.inspect} => #{response.body.inspect}"
      end
    end
  end

end
