class CreateGames < ActiveRecord::Migration
  def change
    create_table :games do |t|
      t.references :black_player, :index => true
      t.references :white_player, :index => true
      t.references :creator, :null => false

      t.string :description
      t.integer :board_size, :limit => 2
      t.integer :handicap, :limit => 2
      t.integer :komi, :limit => 2
      t.string :rule_set
      t.string :time_settings

      t.integer :status, :limit => 2
      t.integer :type, :limit => 2

      t.timestamp :started_at, :finished_at
      t.timestamps
    end
  end
end
