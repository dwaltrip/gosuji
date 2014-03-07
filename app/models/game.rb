class Game < ActiveRecord::Base
  belongs_to :black_player, :class_name => 'User'
  belongs_to :white_player, :class_name => 'User'
  belongs_to :creator, :class_name => 'User'
  belongs_to :winner, :class_name => 'User'
  has_many :boards, -> { order 'move_num ASC' }, inverse_of: :game

  validates :description, length: { maximum: 40 }

  after_touch :clear_association_cache_wrapper

  # game.status constants
  OPEN = 0
  ACTIVE = 1
  END_GAME_SCORING = 2
  FINISHED = 3

  # game.mode constants
  RANKED = 0
  NOT_RANKED = 1

  # game.end_type constants
  WIN_BY_SCORE = 1
  WIN_BY_TIME = 2
  RESIGN = 3
  TIE = 4

  scope :open, lambda { where(:status => OPEN) }
  scope :active, lambda { where(:status => ACTIVE) }


  def active_board
    boards.last
  end

  def previous_board
    boards[-2] if boards.count >= 2
  end

  def move_num
    active_board.move_num
  end

  def next_move_num
    active_board.move_num + 1
  end

  def has_player?(player)
    black_player == player || white_player == player
  end

  def tiles_to_render(player, updates_only=false)
    if updates_only
      tiles_to_update = get_rulebook.tiles_to_update(player_color(player))
      # rulebook doesnt have knowledge of previous board_states
      tiles_to_update.add(previous_board.pos) if previous_board && previous_board.pos

      active_board.pos_nums_and_tile_states(tiles_to_update)
    else
      active_board.pos_nums_and_tile_states
    end
  end

  def tiles_to_render_during_scoring(overwrite_data_store=false)
    scorebot = get_scorebot(overwrite_data_store)
    active_board.pos_nums_and_tile_states(scorebot.changed_tiles)
  end

  def territory_status(pos)
    if finished? && win_by_score?
      (:black if territory_tiles(:black).include?(pos)) || (:white if territory_tiles(:white).include?(pos))
    elsif end_game_scoring?
      get_scorebot.territory_status(pos)
    end
  end

  def territory_tiles(color)
    if finished?
      @territory_tiles = JSON.parse(territory_tiles_serialized) unless @territory_tiles
      @territory_tiles[color.to_s] # json doesn't have symbols, need to convert to string
    end
  end

  def has_dead_stone?(pos)
    if finished? && win_by_score?
      dead_stones.include?(pos)
    elsif end_game_scoring?
      get_scorebot.has_dead_stone?(pos)
    end
  end

  def dead_stones
    @dead_stones ||= JSON.parse(dead_stones_serialized).to_set
  end

  def player_at_move(move_num)
    white_goes_first = (handicap and handicap > 0)
    black_goes_first = (not white_goes_first)

    # move 0 is blank or handicap stone placement -- happens automatically, not from player actions
    if ((move_num % 2 == 1) and white_goes_first) or ((move_num % 2 == 0) and black_goes_first)
      white_player
    else
      black_player
    end
  end

  def viewer(user)
    Struct.new(:type, :color).new(viewer_type(user), player_color(user))
  end

  def viewer_type(user)
    if user == active_player
      :active_player
    elsif user == inactive_player
      :inactive_player
    else
      :observer
    end
  end

  def active_player
    player_at_move(next_move_num)
  end

  def inactive_player
    player_at_move(active_board.move_num)
  end

  def player_color(player = nil)
    (:black if player == black_player) || (:white if player == white_player)
  end

  def white_capture_count
    captured_count(:white)
  end

  def black_capture_count
    captured_count(:black)
  end

  def point_count(player)
    (black_point_count if player == black_player) || (white_point_count if player == white_player)
  end

  def black_point_count
    (get_scorebot.black_point_count if end_game_scoring?) || (black_score if finished?)
  end

  def white_point_count
    (get_scorebot.white_point_count if end_game_scoring?) || (white_score if finished?)
  end

  def point_difference
    point_count(winner) - point_count(opponent(winner)) if end_type == WIN_BY_SCORE
  end

  def opponent(user)
    if user == black_player
      white_player
    elsif user == white_player
      black_player
    else
      logger.warn "-- Game.opponent (game.id: #{id}) -- weird 'user' input, inspecting: #{user.inspect}"
      nil
    end
  end

  def pregame_setup(challenger)
    if challenger.rank.nil? or creator.rank.nil? or challenger.rank == creator.rank
      coin_flip = rand()
      challenger_is_black = (coin_flip < 0.5)
      self.komi = (6.5 if board_size == 19) || 0.5
    else
      challenger_is_black = (challenger.rank < creator.rank)
      self.handicap = (challenger.rank - creator.rank).abs
      self.komi = 0.5
    end

    if challenger_is_black then
      self.black_player = challenger
      self.white_player = creator
    elsif
      self.black_player = creator
      self.white_player = challenger
    end

    self.status = ACTIVE
    save
    Board.initial_board(self)
  end

  def new_move(new_move_pos, current_player)
    rulebook = get_rulebook
    color = player_color(current_player)

    if active? && current_player == active_player && rulebook.playable?(new_move_pos, color)
      rulebook.play_move(new_move_pos, color)
      create_next_board(new_move_pos, color)

      logger.info "-- Game.new_move -- rulebook.captured_stones: #{rulebook.captured_stones.inspect}"
      logger.info "-- Game.new_move -- rulebook.invalid_moves: #{rulebook.invalid_moves.inspect}"
      true
    else
      false
    end
  end

  def pass(current_player)
    if active? && current_player == active_player
      if active_board.pass
        self.status = END_GAME_SCORING
        save
      end

      rulebook = get_rulebook
      rulebook.pass

      new_board = active_board.dup
      new_board.game = self
      new_board.move_num += 1
      new_board.ko = nil
      new_board.pos = nil
      new_board.pass = true
      new_board.captured_stones = captured_count(player_color(current_player))
      new_board.save

      true
    else
      false
    end
  end

  def undo(undoing_player)
    if (active? || end_game_scoring?) && played_a_move?(undoing_player)
      prev_board = active_board
      prev_invalid_moves = get_rulebook.invalid_moves

      if undoing_player == inactive_player
        active_board.destroy # destroy 1 board
      elsif undoing_player == active_player
        boards.to_a[-2..-1].each { |board| board.destroy } # destroy 2 boards
      end

      # this is a presentation detail, we should find a way to move it outside the game model
      stones_with_switched_highlighting = [prev_board.pos, active_board.pos]

      new_rulebook = get_rulebook(force_rebuild=true)
      new_rulebook.calculate_undo_updates(prev_board, prev_invalid_moves, stones_with_switched_highlighting)

      true
    else
      false
    end
  end

  def mark_stone(stone_pos, mark_as)
    if end_game_scoring?
      logger.info "-- Game.mark_stone -- stone_pos: #{stone_pos.inspect}, mark_as: #{mark_as.inspect}"

      action_succeeded =
        if mark_as == "dead"
          get_scorebot.mark_as_dead(stone_pos)
        elsif mark_as == "not_dead"
          get_scorebot.mark_as_not_dead(stone_pos)
        end

      $redis.del(done_scoring_key(black_player), done_scoring_key(white_player)) if action_succeeded
      action_succeeded
    else
      false
    end
  end

  def update_done_scoring_flags(player)
    if has_player?(player) && end_game_scoring?
      $redis.set(done_scoring_key(player), true)
      $redis.expire(done_scoring_key(player), 600)

      black_done, white_done = $redis.mget(done_scoring_key(black_player), done_scoring_key(white_player))
      finish_scoring if black_done && white_done
      true
    else
      false
    end
  end

  def finish_scoring
    scorebot = get_scorebot
    self.black_score = scorebot.black_point_count
    self.white_score = scorebot.white_point_count

    self.end_type = WIN_BY_SCORE

    if black_score > white_score
      self.winner = black_player
    elsif white_score > black_score
      self.winner = white_player
    else
      self.end_type = TIE
      self.winner = nil
    end

    finalize_game
  end

  def resign(player)
    if has_player?(player) && (active? || end_game_scoring?)
      self.black_score = nil
      self.white_score = nil

      self.end_type = RESIGN
      self.winner = opponent(player)

      finalize_game
      true
    else
      false
    end
  end

  def finalize_game
    territory_tiles_to_serialize =
      if end_game_scoring?
        { black: get_scorebot.territory_tiles[GoApp::BLACK_STONE],
          white: get_scorebot.territory_tiles[GoApp::WHITE_STONE] }
      else
        { black: [], white: [] }
      end

    self.territory_tiles_serialized = JSON.dump(territory_tiles_to_serialize)
    self.dead_stones_serialized = JSON.dump((get_scorebot.dead_stones if end_game_scoring?) || [])
    self.black_dead_stone_count = (get_scorebot.dead_stone_count(:black) if end_game_scoring?)
    self.white_dead_stone_count = (get_scorebot.dead_stone_count(:white) if end_game_scoring?)

    self.status = FINISHED
    save
    clear_temp_scoring_data
  end

  def done_scoring_key(player)
    "game-#{id}-player-%s-done" % player.id
  end

  def point_details(player)
    color = player_color(player)
    details = { territory: territory_counts(color), captures: captured_count(color) }
    details[:komi] = komi if color == :white
    details
  end

  def territory_counts(color)
    (territory_tiles(color).size if finished?) || get_scorebot.territory_counts(color)
  end

  def create_next_board(new_move_pos, color)
    next_board = active_board.replicate_and_update(
      new_move_pos,
      captured_count(color),
      player_color(active_player)
    )
    next_board.remove_stones(get_rulebook.captured_stones)

    # playing a new move, ko position can only occur for the waiting player (inactive player)
    ko_pos = get_rulebook.ko_position(player_color(inactive_player))
    next_board.ko = ko_pos if ko_pos
    next_board.save
  end

  def invalid_moves(player=nil)
    if player != nil
      get_rulebook.invalid_moves[player_color(player)]
    else
      get_rulebook.invalid_moves
    end
  end

  def get_ko_position(player)
    logger.info "-- Game.get_ko_position -- get_rulebook.ko_position: #{get_rulebook.ko_position.inspect}"
    get_rulebook.ko_position(player_color(player))
  end

  def show_score?
    end_game_scoring? || (finished? && win_by_score?)
  end

  def active?
    status == ACTIVE
  end

  def finished?
    status == FINISHED
  end

  def open?
    status == OPEN
  end

  def not_open?
    status != OPEN
  end

  def end_game_scoring?
    status == END_GAME_SCORING
  end

  def tie?
    end_type == TIE
  end

  def win_by_resign?
    end_type == RESIGN
  end

  def win_by_score?
    end_type == WIN_BY_SCORE
  end

  def win_by_time?
    end_type == WIN_BY_TIME
  end

  def captured_count(color)
    opposing_color = (:black if color == :white) || (:white if color == :black)
    dead_enemy_stone_count = (dead_stone_count(opposing_color) if finished?) || 0

    captured_stone_count = (last_board(color).captured_stones if last_board(color)) || 0
    captured_stone_count + dead_enemy_stone_count
  end

  def dead_stone_count(color)
    (black_dead_stone_count if color == :black) || (white_dead_stone_count if color == :white)
  end

  def get_rulebook(force_rebuild=false)
    if !@rulebook || force_rebuild
      @rulebook = Rulebook::Handler.new({ size: board_size, board: active_board.tiles })
      @rulebook.set_ko_position(active_board.ko, player_color(active_player)) if active_board.ko
    end
    @rulebook
  end

  def get_scorebot(overwrite_data_store=false)
    @scorebot ||= Scoring::Scorebot.new(
      size: board_size,
      board: active_board.tiles,
      nosql_key: "game-#{id}",
      black_captures: black_capture_count,
      white_captures: white_capture_count,
      komi: komi,
      overwrite: overwrite_data_store
    )
  end

  def clear_temp_scoring_data
    $redis.del("game-#{id}", done_scoring_key(black_player), done_scoring_key(white_player))
  end

  def played_a_move?(player)
    (player_color(player) && ((move_num >= 2) || (move_num == 1 && player == inactive_player)))
  end

  def last_board(color)
    if boards.length > 0
      if !@last_boards || (move_num != @current_move_num)
        b_board, w_board = boards[-1], boards[-2]
        b_board, w_board = w_board, b_board if player_color(player_at_move(b_board.move_num)) == :white
        @last_boards = { black: b_board, white: w_board }
        @current_move_num = move_num
      end

      @last_boards[color]
    end
  end

  private

  def clear_association_cache_wrapper
    clear_association_cache
  end

end
