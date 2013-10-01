class Game < ActiveRecord::Base
  belongs_to :player1, :class_name => 'User'
  belongs_to :player2, :class_name => 'User'

  # status column:
  # 0 - open game, waiting for opponent
  # 1 - active game, currently being played
  # 2 - finished game
  scope :open, lambda { where(:status => 0) }
  scope :active, lambda { where(:status => 1) }

end
