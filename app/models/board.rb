class Board < ActiveRecord::Base
  belongs_to :game, inverse_of: :boards

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
  end

end
