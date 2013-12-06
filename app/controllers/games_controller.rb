class GamesController < ApplicationController
  before_action :find_game, only: [:show, :join, :update]
  before_filter :require_login, :except => :index

  include GamesHelper

  def find_game
    @game = Game.find(params[:id])
  end

  def index
    @open_games = Game.open.order('created_at DESC')
  end

  def new
    @game = Game.new
  end

  def create
    @game = Game.new(
      description: params[:game][:description],
      creator: current_user,
      board_size: params[:game][:board_size],
      status: Game::OPEN,
      mode: Game::NOT_RANKED,
      time_settings: "none"
    )

    if @game.save
      redirect_to games_path, notice: 'Game was created successfully!'
    elsif
      render "new"
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
    render_game_helper
  end

  def update
    logger.info "-- games#update: #{formatted_game_info(@game)}, params[:new_move]= #{params[:new_move].inspect}"

    game_data = @game.new_move(params[:new_move].to_i, current_user)
    render_game_helper(game_data)

    respond_to do |format|
      format.html { render "show" }
      format.js
    end
  end

  # testing and debugging only -- useful for visualing output of rulebook::handler
  def testing_rulebook
    @game = Game.find(params[:id])
    board = @game.active_board
    @viewer_color = @game.player_color(current_user)
    @rulebook_handler = Rulebook::Handler.new(
      size: @game.board_size,
      board: board.tiles,
      active_player_color: @viewer_color
    )
    @rulebook_handler.calculate_invalid_moves

    render file: '/games/testing_rulebook', layout: false
  end


  protected

  def render_game_helper(game_data=nil)
    user = current_user
    current_user_color = @game.player_color(current_user)
    viewer = @game.viewer(user)

    if (game_data == nil) && (viewer.type != :observer)
      game_data = {}
      game_data[:invalid_moves] = @game.get_invalid_moves(current_user)
      updated_tiles = nil
    else
      updated_tiles = game_data[:captured_stones].union(game_data[:invalid_moves][current_user_color])
      updated_tiles.add(@game.active_board.pos) if @game.active_board.pos

      previous_board = @game.previous_active_board
      updated_tiles.add(@game.previous_active_board.pos) if (previous_board && previous_board.pos)

      if @game.active_board.ko
        updated_tiles.add(@game.active_board.ko)
      end
    end
    logger.info "-- render_game_helper -- updated_tiles: #{updated_tiles.inspect}"
    logger.info "-- render_game_helper -- invalid_tiles: #{game_data[:invalid_moves][current_user_color].inspect}"

    @tiles = decorated_tiles(
      @game.active_board,
      game_data[:invalid_moves][current_user_color],
      viewer,
      updated_tiles
    )
    @status_details = @game.status_details
    @viewer_color = current_user_color.to_s
    @active_player_color = @game.player_color(@game.active_player).to_s
    logger.info "-- games#prep_work_for_show_game: #{formatted_game_info(@game)}"
  end

  def decorated_tiles(board, invalid_moves, viewer, updated_tiles=nil)
    if updated_tiles
      tiles = {}
      board.tiles(updated_tiles).each do |pos, tile_state|
        tiles[pos] = TilePresenter.new(
          board_size: board.game.board_size,
          state: tile_state,
          pos: pos,
          viewer: viewer
        )
      end
    else
      tiles = board.tiles.each_with_index.map do |tile_state, pos|
        TilePresenter.new(
          board_size: board.game.board_size,
          state: tile_state,
          pos: pos,
          viewer: viewer
        )
      end
    end

    GoApp::STAR_POINTS[board.game.board_size].each do |star_point_pos|
      tiles[star_point_pos].is_star_point = true if tiles[star_point_pos]
    end

    logger.info "-- games#decorated_tiles -- board.ko= #{board.ko.inspect}, invalid_moves= #{invalid_moves.inspect}"
    tiles[board.pos].is_most_recent_move = true if (board.pos && tiles[board.pos])
    tiles[board.ko].is_ko = true if (board.ko && tiles[board.ko])
    invalid_moves.each { |pos| tiles[pos].is_invalid_move = true if tiles[pos] }

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
