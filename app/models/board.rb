class Board < ActiveRecord::Base
  belongs_to :game, inverse_of: :boards

  BLACK = false
  WHITE = true
  STONE_VALS = { :black => BLACK, :white => WHITE }

  def self.initial_board(game)
    board = new(
      game: game,
      move_num: 0
    )

    # if handicap, create initial board with pre-placed handicap stones, else leave blank
    if game.handicap
      logger.warn '-- inside Board.initial_board -- HANDICAP NOT YET IMPLEMENTED'
    end

    board.save
    board.pretty_print
  end

  def replicate_and_update(pos, color)
    new_board = self.dup
    new_board.game = self.game
    new_board.move_num = self.move_num + 1
    new_board.pos = pos
    new_board.add_stone(pos, color)

    new_board
  end

  def add_stone(pos, color)
    self["pos_#{pos}".to_sym] = STONE_VALS[color]
  end

  def time_left
    self.seconds_remaining
  end

  def get_stones
    black_stones, white_stones = [], []
    (0...self.game.board_size**2).each do |n|
      val = self["pos_#{n}".to_sym]
      if val == BLACK
        black_stones << n
      elsif val == WHITE
        white_stones << n
      end
    end
    [black_stones, white_stones]
  end

  def black_stones
    black_stones, white_stones = self.get_stones
    black_stones
  end

  def white_stones
    black_stones, white_stones = self.get_stones
    white_stones
  end

  def get_positions(size)
    logger.info '-- inside board.get_positions -- entering'

    positions_array = Array.new(size**2) do |n|
      pos = self["pos_#{n}".to_sym]
      tile = {}

      if n % size == 0
        tile[:horiz_edge] = :left
      elsif (n + 1) % size == 0
        tile[:horiz_edge] = :right
      end

      if n >= (size - 1) * size
        tile[:vert_edge] = :bottom
      elsif n < size
        tile[:vert_edge] = :top
      end

      tile[:in_center?] = true if tile.empty?

      if pos == false
        tile[:stone] = :black
      elsif pos == true
        tile[:stone] = :white
      elsif pos != nil
        logger.fatal "!!!! -- board.get_positions -- unexpected value for pos_#{n} column!"
      end

      tile
    end

    self.get_star_points(size).each do |star_point_pos|
      if not positions_array[star_point_pos].has_key? :stone
        positions_array[star_point_pos][:star_point?] = true
      end
    end

    if self.ko
      if positions_array[self.ko][:stone]
        logger.warn "!! -- board.get_positions -- non-empty field marked as ko, this is wrong!"
      end
      positions_array[self.ko][:ko?] = true
    end

    if self.pos
      positions_array[self.pos][:most_recent_stone?] = true
      if not positions_array[self.pos][:stone]
        logger.warn '!! -- board.get_positions -- current move was not marked as stone tile properly!'
      end
    end

    logger.info '-- inside board.get_positions -- exiting'
    positions_array
  end

  ## todo -- star points should be pre-calcuted when server loads and fetched as constants
  def get_star_points(size)
    edge_dist = if (size > 9) then 4 else 3 end
    dists = [edge_dist, size - edge_dist + 1]
    # all boards have corner star points -- can only add middle edge points if board is odd-numbered
    if size % 2 == 1
      dists << (size + 1) / 2
    end

    star_points = []
    # we use the 'dists' array for both x and y, as the star points are completely symmetric
    dists.each do |y|
      dists.each do |x|
        star_points << (size * (y-1)) + x-1
      end
    end
    star_points
  end

  # for debugging, logging, and console experimentation
  def pretty_print(console = false)
    printer = Proc.new do |*args|
      if console
        puts *args
      else
        for log_note in args
          logger.info log_note
        end
      end
    end

    black_stones, white_stones = self.get_stones
    printer.call "---------- pretty printing board with id #{self.id} ----------"
    printer.call "Game Id: #{game_id.inspect}", "Move: #{move_num.inspect}", "Pos: #{pos.inspect}"
    printer.call "Played by: #{game.player_at_move(self.move_num).username.inspect}" if self.move_num > 0
    printer.call "Black Stones: #{black_stones.inspect}", "White Stones: #{white_stones.inspect}"
    printer.call "---------- done pretty printing ----------"
  end

end
