class GamesController < ApplicationController
  before_action :find_game, only: [:show, :join, :update_board]
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
    new_game = Game.new(
      description: params[:description],
      creator: current_user,
      board_size: 19,
      status: Game::OPEN,
      mode: Game::NOT_RANKED,
      time_settings: "none"
    )

    if new_game.save
      redirect_to games_path, notice: 'Game was created successfully!'
    elsif
      redirect_to new_game_path, alert: new_game.errors.full_messages.to_sentence
    end
  end

  def join
    if current_user == @game.creator
      redirect_to games_path, notice: "You can't join a game you created!"
      return
    end

    @game.pregame_setup(current_user)

    redirect_to @game
  end

  def show
    logger.info '-- games#show --'
  end

  def update_board
    board_handler = BoardHelper::BoardHandler.new()
  end

end
