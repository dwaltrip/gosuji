class UsersController < ApplicationController

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

end
