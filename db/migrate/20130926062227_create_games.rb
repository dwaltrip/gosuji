class CreateGames < ActiveRecord::Migration
  def change
    create_table :games do |t|
      t.references :black_player, :index => true
      t.references :white_player, :index => true
      t.references :creator, :null => false
      t.string :description, :limit => 40

      t.integer :winner, :limit => 2
      t.integer :end_type, :limit => 2
      t.integer :score, :limit => 2

      t.integer :board_size, :limit => 2
      t.integer :handicap, :limit => 2
      t.float :komi, :limit => 4
      t.string :time_settings, :limit => 40
      t.string :rule_set, :limit => 20

      t.integer :status, :limit => 2
      t.integer :mode, :limit => 2

      t.timestamp :started_at, :finished_at
      t.timestamps
    end
  end
end
