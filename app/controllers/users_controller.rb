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
      redirect_to games_path, notice: 'Account was created successfully!'
    elsif
      render "new"
    end
  end

  def show
    @started_games = @user.started_games
  end

end
