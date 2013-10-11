class Game < ActiveRecord::Base
  belongs_to :black_player, :class_name => 'User'
  belongs_to :white_player, :class_name => 'User'
  belongs_to :creator, :class_name => 'User'

  # status column:
  # 0 - open game, waiting for opponent
  # 1 - active game, currently being played
  # 2 - finished game
  scope :open, lambda { where(:status => 0) }
  scope :active, lambda { where(:status => 1) }

end
