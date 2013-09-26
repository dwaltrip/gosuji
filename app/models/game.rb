class Game < ActiveRecord::Base
  belongs_to :player1_id, :class_name => 'User'
  belongs_to :player2_id, :class_name => 'User'

end
