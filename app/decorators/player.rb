class Player < BaseDecorator
  attr_reader :color, :user

  def initialize(user, game)
    super(user)

    @game = game
    @user = user
    @color = (:black if @game.black_user == @user) || (:white if @game.white_user == @user)
  end

  def opponent
    if @color
      @opponent ||= (@game.black_player if @color == :white) || (@game.white_player if @color == :black)
    end
  end

  def viewer_type
    if @color
      if (first_to_move? && @game.move_num % 2 == 0) || (!first_to_move? && @game.move_num % 2 == 1)
        :active_player
      else
        :inactive_player
      end
    else
      :observer
    end
  end

  def part_of_game?
    @game.has_user?(@user)
  end
  def not_part_of_game?; !part_of_game? end

  def first_to_move?
    @first_to_move ||= ((@game.handicap? && @color = :white) || (@color == :black))
  end

  def their_turn?
    viewer_type == :active_player
  end

  def not_their_turn?
    viewer_type == :inactive_player
  end

  def played_a_move?
    ((@game.move_num >= 2) || (first_to_move? && @game.move_num >= 1)) if part_of_game?
  end
  def hasnt_played_a_move?; !played_a_move? end

  def point_count
    (@game.black_point_count if @color == :black) || (@game.white_point_count if @color == :white)
  end

end
