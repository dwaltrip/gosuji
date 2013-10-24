class Board < ActiveRecord::Base
  belongs_to :game, inverse_of: :boards

  DB_STONE_MAPPINGS = {
    :black => GoApp::BLACK_STONE,
    :white => GoApp::WHITE_STONE
  }

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
    self["pos_#{pos}".to_sym] = DB_STONE_MAPPINGS[color]
  end

  def time_left
    self.seconds_remaining
  end

  def stone_lists
    black_stones, white_stones = [], []
    (0...self.game.board_size**2).each do |n|
      val = self["pos_#{n}".to_sym]
      if val == GoApp::BLACK_STONE
        black_stones << n
      elsif val == GoApp::WHITE_STONE
        white_stones << n
      end
    end
    [black_stones, white_stones]
  end

  def black_stones
    black_stones, white_stones = self.stone_lists
    black_stones
  end

  def white_stones
    black_stones, white_stones = self.stone_lists
    white_stones
  end

  def positions_array
    Array.new(self.game.board_size**2) { |n| self["pos_#{n}".to_sym] }
  end

  def get_display_data
    size = self.game.board_size
    logger.info '-- inside board.get_display_data -- entering'

    display_data = Array.new(size**2) do |n|
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
        logger.fatal "!!!! -- board.get_display_data -- unexpected value for pos_#{n} column!"
      end

      if tile.has_key?(:stone)
        tile[:invalid_move?] = true
      end

      tile
    end

    self.get_star_points(size).each do |star_point_pos|
      if not display_data[star_point_pos].has_key? :stone
        display_data[star_point_pos][:star_point?] = true
      end
    end

    if self.ko
      if display_data[self.ko][:stone]
        logger.warn "!! -- board.get_display_data -- non-empty field marked as ko, this is wrong!"
      end
      display_data[self.ko][:ko?] = true
    end

    if self.pos
      display_data[self.pos][:most_recent_stone?] = true
      if not display_data[self.pos][:stone]
        logger.warn '!! -- board.get_display_data -- current move was not marked as stone tile properly!'
      end
    end

    logger.info '-- inside board.get_display_data -- exiting'
    display_data
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

    black_stones, white_stones = self.stone_lists
    printer.call "---------- pretty printing board with id #{self.id} ----------"
    printer.call "Game Id: #{game_id.inspect}", "Move: #{move_num.inspect}", "Pos: #{pos.inspect}"
    printer.call "Played by: #{game.player_at_move(self.move_num).username.inspect}" if self.move_num > 0
    printer.call "Black Stones: #{black_stones.inspect}", "White Stones: #{white_stones.inspect}"
    printer.call "---------- done pretty printing ----------"
  end

end
