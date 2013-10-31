class SessionsController < ApplicationController

  def new
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
    user = current_user
    user_log_info = "user.id= #{user.id.inspect}, user.username= #{user.username.inspect}"
    logger.info "-- sessions#destroy: log out. #{user_log_info}"

    session[:user_id] = nil
    @current_user = nil

    redirect_to root_url, :notice => "Logged out!"
  end

end
