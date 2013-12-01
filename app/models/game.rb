class Game < ActiveRecord::Base
  belongs_to :black_player, :class_name => 'User'
  belongs_to :white_player, :class_name => 'User'
  belongs_to :creator, :class_name => 'User'
  has_many :boards, -> { order 'move_num ASC' }, inverse_of: :game

  validates :description, length: { maximum: 40 }

  # game.status constants
  OPEN = 0
  ACTIVE = 1
  FINISHED = 2

  # game.mode constants
  RANKED = 0
  NOT_RANKED = 1

  scope :open, lambda { where(:status => OPEN) }
  scope :active, lambda { where(:status => ACTIVE) }


  ##-- game model instance methods --##

  def active_board
    boards.last
  end

  def next_move_num
    active_board.move_num + 1
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
      player_color(user).to_s
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

  def play_move_and_get_new_invalid_moves(new_move_pos, current_player)
    rulebook_handler = self.get_rulebook_handler(current_player)

    rulebook_handler.play_move(new_move_pos)
    log_msg = "captured_stones= #{rulebook_handler.captured_stones.inspect}"
    logger.info "-- Game.play_move_and_get_new_invalid_moves: #{log_msg}"
    rulebook_handler.calculate_invalid_moves

    self.create_next_board(
      new_move_pos,
      rulebook_handler.captured_stones,
      rulebook_handler.ko_position
    )

    rulebook_handler.invalid_moves
  end

  def create_next_board(new_move_pos, new_captured_stones, ko_pos)
    next_board = self.active_board.replicate_and_update(
      new_move_pos,
      self.previous_captured_count,
      self.player_color(self.active_player)
    )

    logger.info "-- Game.create_next_board: new_captured_stones= #{new_captured_stones.inspect}"
    next_board.remove_stones(new_captured_stones)

    if ko_pos
      logger.info "-- Game.create_next_board, we have a ko! ko_pos= #{ko_pos.inspect}"
      next_board.ko = ko_pos
    end

    next_board.save
  end

  def get_invalid_moves(current_player)
    rulebook_handler = self.get_rulebook_handler(current_player)
    rulebook_handler.calculate_invalid_moves

    rulebook_handler.invalid_moves
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

  def get_rulebook_handler(current_player)
    Rulebook::Handler.new(
      size: self.board_size,
      board: self.active_board.tiles,
      active_player_color: self.player_color(current_player)
    )
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
