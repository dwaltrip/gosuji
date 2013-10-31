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

  def update_board
    logger.info "-- games#update_board, before: #{formatted_game_info(@game)}"
    logger.info "-- games#update_board: params[:new_move]= #{params[:new_move].inspect}"
    @game.process_move_and_update(params[:new_move])

    redirect_to @game
  end


  # testing and debugging only -- useful for visualing output of rulebook::handler
  def testing_rulebook
    @game = Game.find(params[:id])
    board = @game.active_board
    @rulebook_handler = Rulebook::Handler.new(
      size: @game.board_size,
      board: board.tiles
    )

    render file: '/games/testing_rulebook', layout: false
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
    logger.info "-- games#show_setup_helper: #{formatted_game_info(@game)}"
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

    logger.info "-- games#decorated_tiles: board.ko= #{board.ko.inspect}"
    if board.ko
      tiles[board.ko].is_ko = true
    end

    logger.info "-- games#decorated_tiles: invalid_moves= #{invalid_moves.inspect}"
    invalid_moves.each do |pos|
      tiles[pos].is_invalid_move = true
    end

    tiles
  end

  private

  def formatted_game_info(game)
    b = game.active_board
    info_string = "id= #{game.id}, w= #{game.white_player.username}, b= #{game.black_player.username}"
    info_string << ", size= #{game.board_size}, move_num= #{b.move_num.inspect}, pos= #{b.pos.inspect}"
    info_string << ", played by= #{game.player_at_move(b.move_num).username}"
    info_string
  end

end
