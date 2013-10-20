class Game < ActiveRecord::Base
  belongs_to :black_player, :class_name => 'User'
  belongs_to :white_player, :class_name => 'User'
  belongs_to :creator, :class_name => 'User'
  has_many :boards, -> { order 'move_num DESC' }, inverse_of: :game

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
    if move_num == 0
      return nil
    end
    white_goes_first = (self.handicap and self.handicap > 0)
    black_goes_first = (not white_goes_first)

    # move 0 is blank or handicap stone placement -- happens automatically, not from player actions
    if ((move_num % 2 == 1) and white_goes_first) or ((move_num % 2 == 0) and black_goes_first)
      self.white_player
    else
      self.black_player
    end
  end

  def active_player
    self.player_at_move(self.next_move_num)
  end

  def inactive_player
    self.player_at_move(self.active_board.move_num)
  end

  def color(player = nil)
    player = self.active_player if player == nil

    if player == self.black_player
      :black
    elsif player == self.white_player
      :white
    end
  end

  def opponent(user)
    if user == self.black_player
      self.white_player
    elsif user == self.white_player
      self.black_player
    else
      logger.info "-- game.opponent -- #{user.username} is not playing in game id #{self.id}"
      nil
    end
  end

  def pregame_setup(challenger)
    logger.info '-- entering game.pregame_setup --'

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

    logger.info "-- result of coin flip: #{coin_flip}"
    logger.info "-- black: #{self.black_player.username}, white: #{self.white_player.username}"

    self.status = ACTIVE
    self.save

    Board.initial_board(self)

    logger.info '-- exiting game.pregame_setup --'
  end

  def board_display_data
    self.active_board.get_positions(self.board_size)
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

end
