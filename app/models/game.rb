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

end
