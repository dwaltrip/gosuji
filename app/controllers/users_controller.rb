class UsersController < ApplicationController

  def new
    logger.info '-- users#new --'
  end

  def create
    new_user = User.new(params.permit(:username, :email))
    if new_user.save
      logger.info '-- user#create -- new_user.save was successful, redirect to games_path'
      redirect_to games_path, notice: 'Account was created successfully!'
    elsif
      logger.info '-- user#create -- new_user.save create returned false, display errors.full_messages.to_sentence'
      redirect_to new_user_path, alert: new_user.errors.full_messages.to_sentence

      #flash[:alert] = new_user.errors.full_messages.to_sentence
      #render "new"
    end
  end

end
