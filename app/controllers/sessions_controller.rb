class SessionsController < ApplicationController

  def new
    login_alert = session.delete(:login_alert)
    flash.now.alert = login_alert if login_alert
  end

  def create
    user = User.find_by_username(params[:username])
    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_url = session.delete(:login_redirect_url) || root_url

      user_log_info = "user.id= #{user.id.inspect}, user.username= #{user.username.inspect}"
      logger.info "-- sessions#create: successful log in as #{user_log_info}"
      redirect_to redirect_url, :notice => "Logged in!"
    else
      flash.now.alert = "Invalid email or password"
      render "new"
    end
  end

  def destroy
    if current_user.nil?
      logger.info "-- sessions#destroy: log out attempted with current_user = nil"
    else
      user_log_info = "id= #{current_user.id.inspect}, username= #{current_user.username.inspect}"
      logger.info "-- sessions#destroy: log out with current_user -- #{user_log_info}"
    end

    session[:user_id] = nil
    @current_user = nil
    reset_session

    redirect_to games_path, :notice => "Logged out!"
  end

end
