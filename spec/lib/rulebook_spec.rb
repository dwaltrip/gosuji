require 'spec_helper'

describe Rulebook do

  it "marks edge tiles that are empty & surrounded by the enemy as invalid" do
    rulebook = build_rulebook([
      '|_|_|_|b|',
      '|w|_|b|_|',
      '|_|w|_|b|',
      '|w|w|_|_|'
    ])

    rulebook.invalid_moves[:white].to_a.should == [7]
    rulebook.invalid_moves[:black].to_a.should == [8]
  end

  it "marks corner tiles that are empty & surrounded by the enemy as invalid" do
    rulebook = build_rulebook([
      '|_|w|b|_|',
      '|w|_|b|b|',
      '|w|_|_|b|',
      '|_|w|b|_|'
    ])

    rulebook.invalid_moves[:white].to_a.sort.should == [3, 15]
    rulebook.invalid_moves[:black].to_a.sort.should == [0, 12]
  end

  it "marks center tiles that are empty & surrounded by the enemy as invalid" do
    rulebook = build_rulebook([
      '|b|b|b|_|_|',
      '|b|_|b|_|_|',
      '|b|b|w|w|_|',
      '|_|w|_|w|_|',
      '|_|w|w|_|_|',
    ])

    rulebook.invalid_moves[:white].to_a.should == [6]
    rulebook.invalid_moves[:black].to_a.should == [17]
  end

end

# ------------------------------------------------------------------------------------------
# helper methods for using human readable string representations of game board while testing
# ------------------------------------------------------------------------------------------

def build_rulebook(rows)
  board = make_board(rows)
  size = rows[0].gsub('|', '').length

  raise "Row inputs do not have same number of tiles" if size**2 != board.length

  Rulebook::Handler.new(board: board, size: Integer(size))
end

def make_board(rows)
  rows.flat_map do |row|
    match_data = /\A\|([wb_]\|)+\z/.match(row)
    unless match_data && match_data.string == row
      raise "Improperly formatted row string: #{row.inspect}"
    end

    # ignore first and last edge spacer (vertical bar '|')
    row[1..-2].split('|').map { |char| CHAR_MAP[char] }
  end
end

CHAR_MAP = {
  'b' => GoApp::BLACK_STONE,
  'w' => GoApp::WHITE_STONE,
  '_' => GoApp::EMPTY_TILE
}
