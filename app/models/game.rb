class Game < ActiveRecord::Base
  belongs_to :black_player, :class_name => 'User'
  belongs_to :white_player, :class_name => 'User'
  belongs_to :creator, :class_name => 'User'
  has_many :boards, -> { order 'move_num ASC' }, inverse_of: :game

  validates :description, length: { maximum: 40 }

  after_touch :clear_association_cache

  # game.status constants
  OPEN = 0
  ACTIVE = 1
  END_GAME_SCORING = 2
  FINISHED = 3

  # game.mode constants
  RANKED = 0
  NOT_RANKED = 1

  scope :open, lambda { where(:status => OPEN) }
  scope :active, lambda { where(:status => ACTIVE) }

  ##-- game model instance methods --##

  def active_board
    boards.last
  end

  def previous_board
    if boards.count >= 2
      boards[-2]
    end
  end

  def move_num
    active_board.move_num
  end

  def next_move_num
    active_board.move_num + 1
  end

  def tiles_to_render(player, just_played_new_move)
    if just_played_new_move
      tiles_to_update = self.get_rulebook.tiles_to_update(self.player_color(player))

      # rulebook doesnt have knowledge of previous board_states
      if self.previous_board && self.previous_board.pos
        tiles_to_update.add(self.previous_board.pos)
      end

      self.active_board.pos_nums_and_tile_states(tiles_to_update)
    else
      self.active_board.pos_nums_and_tile_states
    end
  end

  def player_at_move(move_num)
    white_goes_first = (self.handicap and self.handicap > 0)
    black_goes_first = (not white_goes_first)

    # move 0 is blank or handicap stone placement -- happens automatically, not from player actions
    if ((move_num % 2 == 1) and white_goes_first) or ((move_num % 2 == 0) and black_goes_first)
      self.white_player
    else
      self.black_player
    end
  end

  def viewer(user)
    Struct.new(:type, :color).new(
      viewer_type(user),
      player_color(user)
    )
  end

  def viewer_type(user)
    if user == self.active_player
      :active_player
    elsif user == self.inactive_player
      :inactive_player
    else
      :observer
    end
  end

  def active_player
    self.player_at_move(self.next_move_num)
  end

  def inactive_player
    self.player_at_move(self.active_board.move_num)
  end

  def player_color(player = nil)
    if player == self.black_player
      :black
    elsif player == self.white_player
      :white
    end
  end

  def white_capture_count
    @status_details ||= status_details
    @status_details[:captures][:white]
  end

  def black_capture_count
    @status_details ||= status_details
    @status_details[:captures][:black]
  end

  def status_details
    black_board, white_board = self.boards_by_color(last_only = true)

    details = {}
    details[:captures] = {
      black: black_board ? (black_board.captured_stones || 0) : 0,
      white: white_board ? (white_board.captured_stones || 0) : 0
    }
    if self.time_settings && self.time_settings.length > 0
      details[:time_left] = {
        black: black_board ? black_board.time_left : nil,
        white: white_board ? white_board.time_left : nil
      }
    end
    details
  end

  def opponent(user)
    if user == self.black_player
      self.white_player
    elsif user == self.white_player
      self.black_player
    else
      logger.warn "-- Game.opponent: #{user.username} is not playing in game id #{self.id}"
      nil
    end
  end

  def pregame_setup(challenger)
    if challenger.rank.nil? or creator.rank.nil? or challenger.rank == creator.rank
      coin_flip = rand()
      challenger_is_black = (coin_flip < 0.5)
      self.komi = 6.5
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
    self.save
    Board.initial_board(self)
  end

  def new_move(new_move_pos, current_player)
    rulebook = self.get_rulebook
    color = self.player_color(current_player)

    if self.active? && current_player == self.active_player && rulebook.playable?(new_move_pos, color)
      rulebook.play_move(new_move_pos, color)

      self.create_next_board(new_move_pos)

      logger.info "-- Game.new_move -- rulebook.captured_stones: #{rulebook.captured_stones.inspect}"
      logger.info "-- Game.new_move -- rulebook.invalid_moves: #{rulebook.invalid_moves.inspect}"

      true
    else
      false
    end
  end

  def pass(current_player)
    if self.active? && current_player == self.active_player
      if self.active_board.pass
        self.status = END_GAME_SCORING
      end

      rulebook = self.get_rulebook
      rulebook.pass

      new_board = self.active_board.dup
      new_board.game = self
      new_board.move_num += 1
      new_board.ko = nil
      new_board.pos = nil
      new_board.pass = true
      new_board.save

      true
    else
      false
    end
  end

  def undo(undoing_player)
    if [ACTIVE, END_GAME_SCORING].include?(self.status) && self.played_a_move(undoing_player)
      prev_board = self.active_board
      prev_invalid_moves = self.get_rulebook.invalid_moves

      # destroy 1 board
      if undoing_player == self.inactive_player
        self.active_board.destroy
      # destroy 2 boards
      elsif undoing_player == self.active_player
        self.boards.to_a[-2..-1].each { |board| board.destroy }
      end

      new_rulebook = self.get_rulebook(force_rebuild=true)
      new_rulebook.calculate_undo_updates(prev_board, prev_invalid_moves, self.active_board.pos)

      true
    else
      false
    end
  end

  def create_next_board(new_move_pos)
    next_board = self.active_board.replicate_and_update(
      new_move_pos,
      self.previous_captured_count,
      self.player_color(self.active_player)
    )
    next_board.remove_stones(self.get_rulebook.captured_stones)

    # playing a new move, ko position can only occur for the waiting player (inactive player)
    ko_pos = self.get_rulebook.ko_position(self.player_color(self.inactive_player))
    next_board.ko = ko_pos if ko_pos
    next_board.save
  end

  def invalid_moves(player=nil)
    if player != nil
      self.get_rulebook.invalid_moves[self.player_color(player)]
    else
      self.get_rulebook.invalid_moves
    end
  end

  def get_ko_position(player)
    logger.info "-- Game.get_ko_position -- self.get_rulebook.ko_position: #{self.get_rulebook.ko_position.inspect}"
    self.get_rulebook.ko_position(self.player_color(player))
  end

  def active?
    self.status == ACTIVE
  end

  def finished?
    self.status == FINISHED
  end

  def not_open?
    self.status != OPEN
  end

  def end_game_scoring?
    self.status == END_GAME_SCORING
  end

  def previous_captured_count
    color = self.player_color(self.active_player)
    last_black_board, last_white_board = boards_by_color(last_only = true)

    if color == :black
      board = last_black_board
    elsif color == :white
      board = last_white_board
    end

    if board
      log_msg = "color= #{color.inspect}, move_num= #{board.move_num.inspect}, pos= #{board.pos.inspect}"
      log_msg << ", captured_stones= #{board.captured_stones.inspect}"
      logger.info "-- Game.previous_captured_count: #{log_msg}"
      board.captured_stones
    else
      logger.info "-- Game.previous_captured_count: no previous board for #{color}"
      0
    end
  end

  def get_rulebook(force_rebuild=false)
    if (not @rulebook) or force_rebuild
      params = { size: self.board_size, board: self.active_board.tiles }
      @rulebook = Rulebook::Handler.new(params)

      if self.active_board.ko
        @rulebook.set_ko_position(self.active_board.ko, self.player_color(self.active_player))
      end
    end

    @rulebook
  end

  def played_a_move(player)
    (player_color(player) && ((move_num >= 2) || (move_num == 1 && player == inactive_player)))
  end

  def boards_by_color(last_only = false)
    if boards.length == 0
      return
    elsif last_only
      b1, b2 = boards[-1], boards[-2]
      if self.player_color(self.player_at_move(b1.move_num)) == :black
        black_board, white_board = b1, b2
      else
        black_board, white_board = b2, b1
      end
      [black_board, white_board]
    else
      black_boards, white_boards = [], []
      boards.each do |b|
        if b.move_num > 0
          black_boards << b if self.player_color(self.player_at_move(b.move_num)) == :black
          white_boards << b if self.player_color(self.player_at_move(b.move_num)) == :white
        end
      end
      [black_boards, white_boards]
    end
  end

end
