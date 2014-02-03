class GamesController < ApplicationController
  before_filter :require_login, :except => :index
  before_action :find_game, only: [:show, :join, :new_move, :pass_turn, :undo_turn, :request_undo]

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
    pretty_log_game_info("-- games#show -- ")
    @connection_id = generate_token
    @tiles = decorated_tiles(current_user, render_updates_only=false)
  end


  def new_move
    update_helper @game.new_move(params[:new_move].to_i, current_user)
  end

  def pass_turn
    update_helper @game.pass(current_user)
  end

  def undo_turn
    undo_data = decrypt(params[:undo_data])
    move_num = undo_data[:move_num] if undo_data
    valid_undo_approval = (params[:undo_status] == "approved" && move_num == @game.move_num)

    undo_requester = @game.opponent(current_user)
    update_helper (valid_undo_approval && @game.undo(undo_requester))
  end

  def request_undo
    # the move_num value created here is verified in games#undo_turn if the undo request is approved
    approval_form = render_to_string(partial: 'undo_approval_form', locals: {
      undo_data: encrypt({ move_num: @game.move_num })
    })
    send_event_data_to_other_clients(event_name: "undo-request", payload: { approval_form: approval_form })
    respond_to { |format| format.js }
  end


  private

  def update_helper(update_action_was_successful)
    pretty_log_game_info("-- games#update_helper -- ")

    if update_action_was_successful
      @tiles = decorated_tiles(current_user)
      logger.info "-- games#update_helper -- @game.invalid_moves: #{@game.invalid_moves.inspect}"
      logger.info "-- games#update_helper -- @tiles.length: #{@tiles.length}"

      # if ever necessary, we can merge additional data into the opponenet_data hash
      # the 'JSON.parse' foolishness is needed as I couldn't make Jbuilder skip the actual JSON string encoding
      opponent = @game.opponent(current_user)
      opponent_data = JSON.parse(render_to_string(template: 'games/update', formats: [:json],
        locals: { tiles: decorated_tiles(opponent), user: opponent }
      ))

      logger.info "-- games#update_helper -- opponent_data: #{opponent_data.inspect}"
      send_event_data_to_other_clients event_name: "game-update", payload: opponent_data

      respond_to do |format|
        format.json { render 'games/update', locals: { tiles: @tiles, user: current_user } }
      end
    else
      render nothing: true
    end
  end

  def decorated_tiles(player, render_updates_only=true)
    logger.info "-- games#decorated_tiles -- #{player.username} as #{@game.player_color(player)}"
    viewer = @game.viewer(player)
    last_pos = @game.active_board.pos
    ko_pos = @game.get_ko_position(player)

    @game.tiles_to_render(player, render_updates_only).map do |pos, tile_state|
      new_tile = TilePresenter.new(
        board_size: @game.board_size,
        state: tile_state,
        pos: pos,
        viewer: viewer,
        invalid_moves: @game.invalid_moves
      )
      new_tile.is_most_recent_move = true if pos == last_pos
      new_tile.is_ko = true if pos == ko_pos
      new_tile
    end
  end


  def send_event_data_to_other_clients(event_data)
    event_data[:connection_id_to_skip] = params[:connection_id]
    event_data[:room_id] = @room_id
    logger.info "-- games#send_event_data_to_other_clients -- event_data: #{event_data.inspect}"
    $redis.publish "game-events", JSON.dump(event_data)
  end

  def find_game
    @game = Game.find(params[:id])
    @room_id = "game-#{@game.id}"
  end

  def pretty_log_game_info(prefix)
    inspect_prefix = @game.inspect.split[0] # use this to insert game.object_id into the game.inspect output
    log_msg1 = "game: #{inspect_prefix} object_id: #{@game.object_id},#{@game.inspect[(inspect_prefix.length)..-1]}"
    log_msg2 = "game.active_board: #{@game.active_board.inspect}"
    logger.info "#{prefix}#{log_msg1}"
    logger.info "#{prefix}#{log_msg2}"
  end

end
