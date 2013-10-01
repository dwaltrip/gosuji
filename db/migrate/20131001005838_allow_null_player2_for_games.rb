class AllowNullPlayer2ForGames < ActiveRecord::Migration
  def change
    change_column_null :games, :player2_id, true
  end
end
