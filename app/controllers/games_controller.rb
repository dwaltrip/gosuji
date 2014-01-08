class GamesController < ApplicationController
  before_filter :require_login, :except => :index
  before_action :find_game, only: [:show, :join, :update]

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
    logger.info "-- games#show -- #{formatted_game_info(@game)}"
    render_game_helper
  end

  def update
    logger.info "-- games#update -- #{formatted_game_info(@game)}, params[:new_move]= #{params[:new_move].inspect}"

    if params.key?(:new_move) && @game.new_move(params[:new_move].to_i, current_user)
      @just_played_new_move = true
      render_game_helper

      opponent = @game.opponent(current_user)
      opponent_tiles = decorated_tiles(opponent).map do |pos, tile|
        { pos: pos,
          html: tile.to_html(@game.viewer(opponent)) }
      end

      # publish updated info to listener on Node.js server which then updates opponent client via websockets
      # will later add in very similar functionality for any observing users (not playing in the game)
      $redis.publish 'game-updates', ActiveSupport::JSON.encode({
        room_id: "game-#{@game.id}",
        move_id: params[:move_id],
        tiles: opponent_tiles,
        invalid_moves: @game.invalid_moves(opponent),
        header_html: render_to_string(partial: 'game_stats', locals: @header_inputs)
      })
    end

    respond_to do |format|
      format.html { render "show" }
      format.js
    end
  end

  # testing and debugging only -- useful for visualing output of rulebook::handler
  def testing_rulebook
    @game = Game.find(params[:id])
    @rulebook = Rulebook::Handler.new(
      size: @game.board_size,
      board: @game.active_board.tiles,
      active_player_color: @game.player_color(current_user)
    )
    render file: '/games/testing_rulebook', layout: false
  end

  protected

  def render_game_helper
    @tiles = decorated_tiles(current_user)
    @header_inputs = { game: @game, active_color: @game.player_color(@game.active_player).to_s }
    logger.info "-- games#render_game_helper -- @game.invalid_moves: #{@game.invalid_moves.inspect}"
  end

  def decorated_tiles(player)
    if @just_played_new_move
      tiles = {}
    else
      tiles = Array.new(@game.board_size ** 2)
    end

    viewer = @game.viewer(player)
    @game.tiles_to_render(player, @just_played_new_move).each do |pos, tile_state|
      tiles[pos] = TilePresenter.new(
        board_size: @game.board_size,
        state: tile_state,
        pos: pos,
        viewer: viewer,
        invalid_moves: @game.invalid_moves
      )
    end
    log_msg = "#{player.username.inspect} as #{@game.player_color(player).inspect} -- tiles.length: #{tiles.length}"
    logger.info "-- games#decorated_tiles -- #{log_msg}"

    if @game.active_board.pos && tiles[@game.active_board.pos]
      tiles[@game.active_board.pos].is_most_recent_move = true
    end
    if @game.get_ko_position(player) && tiles[@game.get_ko_position(player)]
      tiles[@game.get_ko_position(player)].is_ko = true
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
