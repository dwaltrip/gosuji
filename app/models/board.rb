class Board < ActiveRecord::Base
  belongs_to :game, inverse_of: :boards
end
