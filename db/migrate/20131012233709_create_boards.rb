class CreateBoards < ActiveRecord::Migration
  def change
    create_table :boards do |t|
      t.references :game, :index => true
      t.integer :move_num, :null => false, :limit => 2

      t.integer :pos, :limit => 2
      t.integer :ko, :limit => 2
      t.integer :captured_stones, :limit => 2
      t.boolean :pass, :default => false

      # only store time remaining info for one player, the one who made current move
      t.integer :seconds_remaining, :limit => 2
      # extra time fields for various OT systems, period timing systems, etc
      t.integer :time_field_1, :limt => 2
      t.integer :time_field_2, :limt => 2

      # non bit-string approach, using booleans for simplicity to label board state
      # nil = empty tile, false = black stone, true = white stone
      # for consistency let us make everything 0-indexed
      (0...GoApp::BOARD_SIZE**2).each do |n|
        t.boolean "pos_#{n}".to_sym, :default => nil
      end

      # bit strings with one bit per square (hence BOARD_SIZE**2)
      # uses less than 1/3 space of the boolean approach, but more complicated
      # querying on board state would also probably be slower this way
      # keeping this here as a reminder of another possible approach
      #t.column :black_positions, "bit(#{GoApp::BOARD_SIZE**2})"
      #t.column :white_positions, "bit(#{GoApp::BOARD_SIZE**2})"

      t.timestamps
    end
  end
end
