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
    @tiles = @game.board_display_data
  end

  def update_board
    logger.info "-- games#update_board -- entering"

    # board handler is not fully functional yet, still need to finish 'valid moves' calculation step
    ##### board_handler = BoardHelper::BoardHandler.new()

    logger.info "-- params[:new_move] = #{params[:new_move].inspect} --"
    new_board = @game.process_move_and_update(params[:new_move])

    logger.info "-- games#update_board -- rendering"
    redirect_to @game
  end

end
