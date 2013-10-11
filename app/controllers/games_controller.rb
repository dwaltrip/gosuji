class GamesController < ApplicationController
  before_action :find_game, only: [:show, :update_board]
  before_filter :require_login, :except => :index

  def find_game
    @game = Game.find(params[:id])
  end

  def index
    @open_games = Game.open.order('created_at DESC')
  end

  def new
  end

  def create
    new_game = Game.new(description: params[:description], status: 0, creator: current_user)
    if new_game.save
      redirect_to games_path, notice: 'Game was created successfully!'
    elsif
      redirect_to new_game_path, alert: new_game.errors.full_messages.to_sentence
    end
  end

  def show
    logger.info '-- games#show --'
  end

  def update_board
    board_handler = BoardHelper::BoardHandler.new()
  end

end
