class GamesRenamePlayerToUser < ActiveRecord::Migration
  def change
    rename_column :games, :black_player_id, :black_user_id
    rename_column :games, :white_player_id, :white_user_id
    rename_column :games, :winner_id, :winning_user_id
  end
end
