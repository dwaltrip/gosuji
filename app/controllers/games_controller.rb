class GamesController < ApplicationController
  before_filter :require_login, :except => :index
  before_action :find_game, only: [:show, :join, :update, :request_undo]
  after_action :undo_request_cleanup, only: [:show, :update]

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
    logger.info "-- games#update -- #{formatted_game_info(@game)}"
    @invalid_request = true

    if params.key?(:new_move)
      if @game.new_move(params[:new_move].to_i, current_user)
        @just_played_move = true
        @invalid_request = false
        @event_id = params[:move_id]
      end

    elsif params.key?(:pass)
      if @game.pass(current_user)
        @just_played_move = true
        @invalid_request = false
        @event_id = params[:move_id]
      end

    elsif params.key?(:undo)
      # current player has approved the undo which the opponent requested
      if params[:undo] == "approved" && @game.undo(@game.opponent(current_user))
        logger.info "-- games#update -- undo performed for opponent!"
        @undo_performed = true
        @invalid_request = false
        @event_id = "#{params[:request_id]}-performed"
      end

    else
      logger.info "-- games#update -- none of the expected data was found in params, which is a bit fishy"
    end
    @render_updates = @just_played_move || @undo_performed

    vars = ["@invalid_request", "@just_played_move", "@undo_performed", "@undo_rejected", "@event_id"]
    logger.info "-- games#update -- #{(vars.map {|v| "#{v}: #{instance_variable_get(v.intern).inspect}"}).join(", ")}"

    if @render_updates && !@invalid_request
      render_game_helper

      opponent = @game.opponent(current_user)
      opponent_tiles = decorated_tiles(opponent).map do |pos, tile|
        { pos: pos,
          html: tile.to_html(@game.viewer(opponent)) }
      end

      payload = {
        tiles: opponent_tiles,
        invalid_moves: @game.invalid_moves(opponent),
        header_html: render_to_string(partial: 'game_stats', locals: { game: @game })
      }
      # undo button needs to re-disabled if the only move for a player is undone
      # special case, handled awkwardly here for now
      payload[:disable_undo_button] = true if (@undo_performed && @game.move_num < 2)

      update_data = {
        event_type: "game-update",
        room_id: "game-#{@game.id}",
        event_id: @event_id,
        payload: payload
      }
      # publish updated info to redis subscriber on Node.js server which then updates opponent client via websockets
      $redis.publish "game-events", ActiveSupport::JSON.encode(update_data)
    end

    respond_to do |format|
      format.html { render "show" }
      format.js
    end
  end

  def request_undo
    # if nil (not in session yet), then to_i converts nil to 0
    session[:request_count] = session[:request_count].to_i + 1

    id_params = ["game", @game.id, "move", @game.move_num, @game.player_color(current_user), session[:request_count]]
    @request_id = id_params.join("-")
    logger.info "-- games#request_undo -- request_id: #{@request_id.inspect}"
    approval_form_html = render_to_string(partial: 'undo_approval_form', locals: { request_id: @request_id })

    $redis.publish "game-events", ActiveSupport::JSON.encode({
      event_type: "undo-request",
      room_id: "game-#{@game.id}",
      request_id: @request_id,
      payload: { undo_approval_form: approval_form_html }
    })

    respond_to { |format| format.js }
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
    logger.info "-- games#render_game_helper -- @game.invalid_moves: #{@game.invalid_moves.inspect}"
  end

  def decorated_tiles(player)
    render_subset_only = (@just_played_move || @undo_performed)

    if render_subset_only
      tiles = {}
    else
      tiles = Array.new(@game.board_size ** 2)
    end

    viewer = @game.viewer(player)
    @game.tiles_to_render(player, render_subset_only).each do |pos, tile_state|
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

  def find_game
    @game = Game.find(params[:id])
  end

  def undo_request_cleanup
    session[:request_count] = 0
  end

  def formatted_game_info(game)
    b = game.active_board
    info_string = "id= #{game.id}, w= #{game.white_player.username}, b= #{game.black_player.username}"
    info_string << ", size= #{game.board_size}, move_num= #{b.move_num.inspect}, pos= #{b.pos.inspect}"
    info_string << ", played by= #{game.player_at_move(b.move_num).username}"
    info_string
  end

end
