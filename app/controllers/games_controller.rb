class GamesController < ApplicationController

  def index
    logger.info '-- games#index --'
    @open_games = Game.open.order('created_at DESC')
  end

  def new
    logger.info '-- games#new --'
  end

  def create
    new_game = Game.new(description: params[:description],
                        status: 0 # games are initially open (waiting for an opponent)
                       )
    new_game.player1 = User.find(params[:p1_id])
    if new_game.save
      logger.info '-- games#create -- new_game.save was successful, redirect to games_path (maybe redirect_to'
      redirect_to games_path, notice: 'Game was created successfully!'
    elsif
      logger.info '-- game#create -- new_game.save create returned false, display errors.full_messages.to_sentence'
      redirect_to new_game_path, alert: new_game.errors.full_messages.to_sentence
    end
  end

end
