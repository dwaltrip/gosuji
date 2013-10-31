class UsersController < ApplicationController
  before_filter :require_login, :only => :show
  before_action :find_user, only: [:show]

  def find_user
    @user = User.find(params[:id])
  end

  def new
  end

  def create
    @user = User.new(params.permit(:username, :email, :password, :password_confirmation))
    if @user.save
      logger.info "-- users#create: new user created. #{user_log_info}"
      redirect_to games_path, notice: 'Account was created successfully!'
    elsif
      render "new"
    end
  end

  def show
    logger.info "-- users#show: #{user_log_info}"
    @started_games = @user.started_games
  end

  protected

  def user_log_info
    "user.id= #{@user.id.inspect}, user.username= #{@user.username.inspect}"
  end

end
