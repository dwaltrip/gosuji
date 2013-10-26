class GamesController < ApplicationController
  before_action :find_game, only: [:show, :join, :update_board]
  before_filter :require_login, :except => :index

  include GamesHelper

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
    show_setup_helper
  end

  def testing_rulebook
    # testing and debugging only -- useful for visualing output of rulebook::handler
    logger.info '-- games#testing_rulebook -- entering'

    @game = Game.find(params[:id])

    board = @game.active_board
    board.pretty_print

    @rulebook_handler = Rulebook::Handler.new(
      size: @game.board_size,
      board: board.tiles
    )

    logger.info '-- games#testing_rulebook -- exiting'
    render file: '/games/testing_rulebook', layout: false
  end

  def update_board
    logger.info "-- games#update_board -- entering"

    logger.info "-- params[:new_move] = #{params[:new_move].inspect} --"
    @game.process_move_and_update(params[:new_move])

    logger.info "-- games#update_board -- rendering"
    redirect_to @game
  end


  protected

  def show_setup_helper(rulebook_handler=nil)
    #if handler == nil
    #  rulebook_handler = Rulebook::Handler.new(
    #    size: @game.board_size,
    #    board: @game.active_board
    #  )
    #end

    @tiles = decorated_tiles(
      @game.active_board,
      [],
      @game.viewer(current_user)
    )

    @status_details = @game.status_details
    @viewer_color = @game.player_color(current_user).to_s
    @active_player_color = @game.player_color(@game.active_player).to_s

    @game.active_board.pretty_print
  end

  def decorated_tiles(board, invalid_moves, viewer)
    tiles = board.tiles.each_with_index.map do |tile_state, pos|
      TilePresenter.new(
        board_size: board.game.board_size,
        state: tile_state,
        pos: pos,
        viewer: viewer
      )
    end

    GoApp::STAR_POINTS[board.game.board_size].each do |star_point_pos|
      tiles[star_point_pos].is_star_point = true
    end

    if board.pos
      tiles[board.pos].is_most_recent_move = true
    end

    if board.ko
      tiles[board.ko].is_ko = true
    end

    invalid_moves.each do |pos|
      tiles[pos].is_invalid_move = true
    end

    tiles
  end

end
