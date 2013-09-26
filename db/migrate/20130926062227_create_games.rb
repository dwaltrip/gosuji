class CreateGames < ActiveRecord::Migration
  def change
    create_table :games do |t|
      t.references :player1, :index => true, :null => false
      t.references :player2, :index => true, :null => false

      t.integer :status, :limit => 2
      t.integer :board_size, :limit => 2
      t.string :time_settings

      t.timestamp :started_at, :finished_at
      t.timestamps
    end
  end
end
