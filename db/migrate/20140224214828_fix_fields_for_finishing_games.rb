class FixFieldsForFinishingGames < ActiveRecord::Migration
  def change
    remove_column :games, :score
    remove_column :games, :winner

    add_column :games, :winner_id, :integer
    add_index :games, :winner_id

    add_column :games, :black_score, :float
    add_column :games, :white_score, :float

    add_column :games, :dead_stones_serialized, :text
    add_column :games, :territory_tiles_serialized, :text
    add_column :games, :black_dead_stone_count, :integer, limit: 2
    add_column :games, :white_dead_stone_count, :integer, limit: 2
  end
end
