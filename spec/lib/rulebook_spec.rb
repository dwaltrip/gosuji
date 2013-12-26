require 'spec_helper'

WHITE = GoApp::WHITE_STONE
BLACK = GoApp::BLACK_STONE
Group = Struct.new(:color, :members, :liberties)

describe Rulebook do
  context "when analyzing the board (rulebook.analyze_board)" do

    let(:rulebook) do
      build_rulebook([
        '|_|b|_|w|_|_|b|w|',
        '|_|b|_|w|w|_|b|_|',
        '|_|_|w|_|_|b|b|b|',
        '|w|w|w|_|b|_|_|_|',
        '|_|_|_|_|_|_|b|b|',
        '|w|w|w|w|w|_|b|_|',
        '|b|b|b|b|w|b|_|b|',
        '|_|b|_|b|w|b|_|w|'
      ])
    end
    # correct_groups is hand identified from above board
    let(:correct_groups) do
      [
        Group.new(BLACK, Set.new([1, 9]), Set.new([0, 2, 8, 10, 17])),
        Group.new(WHITE, Set.new([3, 11, 12]), Set.new([2, 4, 10, 13, 19, 20])),
        Group.new(BLACK, Set.new([6, 14, 21, 22, 23]), Set.new([5, 13, 15, 20, 29, 30, 31])),
        Group.new(WHITE, Set.new([7]), Set.new([15])),
        Group.new(WHITE, Set.new([18, 24, 25, 26]), Set.new([16, 17, 10, 19, 27, 32, 33, 34])),
        Group.new(BLACK, Set.new([28]), Set.new([20, 27, 29, 36])),
        Group.new(BLACK, Set.new([38, 39, 46]), Set.new([30, 31, 37, 45, 47, 54])),
        Group.new(WHITE, Set.new([40, 41, 42, 43, 44, 52, 60]), Set.new([32, 33, 34, 35, 36, 45])),
        Group.new(BLACK, Set.new([48, 49, 50, 51, 57, 59]), Set.new([56, 58])),
        Group.new(BLACK, Set.new([53, 61]), Set.new([45, 54, 62])),
        Group.new(BLACK, Set.new([55]), Set.new([47, 54])),
        Group.new(WHITE, Set.new([63]), Set.new([62]))
      ]
    end

    it "identifies the correct members for each group of stones" do
      rulebook.members.size.should == correct_groups.size

      correct_groups.each do |correct_group|
        random_group_member = correct_group.members.to_a.pop
        group_id = rulebook.group_ids[random_group_member]

        correct_group.members.each do |stone_pos|
          rulebook.group_ids[stone_pos].should == group_id
        end

        rulebook.members[group_id].should == correct_group.members
      end
    end

    it "assigns correct liberties for each group" do
      rulebook.liberties.size.should == correct_groups.size

      correct_groups.each do |correct_group|
        group_id = rulebook.group_ids[correct_group.members.to_a.pop]
        rulebook.liberties[group_id].should == correct_group.liberties
      end
    end

    it "assigns correct color for each group" do
      rulebook.colors.size.should == correct_groups.size

      correct_groups.each do |correct_group|
        group_id = rulebook.group_ids[correct_group.members.to_a.pop]
        rulebook.colors[group_id].should == correct_group.color
      end
    end
  end

  context "when finding invalid moves (rulebook.invalid_moves)" do

    # inside calculate_invalid_moves, block starting with: all_liberties.each do |empty_pos|
    context "and examining empty tiles surrounded by stones of a single color" do

      it "marks single edge tiles as invalid for opposing color" do
        rulebook = build_rulebook([
          '|_|_|_|b|',
          '|w|_|b|_|',
          '|_|w|_|b|',
          '|w|w|_|_|'
        ])
        rulebook.invalid_moves[:white].to_a.should == [7]
        rulebook.invalid_moves[:black].to_a.should == [8]
      end

      it "marks single corner tiles as invalid for opposing color" do
        rulebook = build_rulebook([
          '|_|w|b|_|',
          '|w|_|b|b|',
          '|w|_|_|b|',
          '|_|w|b|_|'
        ])
        rulebook.invalid_moves[:white].to_a.sort.should == [3, 15]
        rulebook.invalid_moves[:black].to_a.sort.should == [0, 12]
      end

      it "marks single center tiles the enemy as invalid for opposing color" do
        rulebook = build_rulebook([
          '|b|b|b|_|_|',
          '|b|_|b|_|_|',
          '|b|b|w|w|_|',
          '|_|w|_|w|_|',
          '|_|w|w|_|_|'
        ])
        rulebook.invalid_moves[:white].to_a.should == [6]
        rulebook.invalid_moves[:black].to_a.should == [17]
      end

      it "DOES NOT mark tile groups of size 2 (or more) as invalid" do
        rulebook = build_rulebook([
          '|b|b|b|_|_|b|',
          '|b|_|_|b|b|b|',
          '|b|b|b|_|_|_|',
          '|w|w|w|w|w|w|',
          '|_|w|_|_|w|_|',
          '|_|w|w|w|_|_|'
        ])
        rulebook.invalid_moves[:white].should be_empty
        rulebook.invalid_moves[:black].should be_empty
      end
    end

    # block starting with: single_liberty_groups.each do |single_lib_group_id, libs|

    context "and examining stone groups with a single liberty (and are non-killing moves)" do
      it "marks the liberty tile as invalid for that player" do
        rulebook = build_rulebook([
          '|_|b|w|w|w|_|b|',
          '|_|b|b|b|b|b|b|',
          '|_|_|_|_|_|_|_|',
          '|w|w|w|w|_|b|b|',
          '|w|b|b|w|_|b|_|',
          '|b|b|_|w|_|b|w|',
          '|w|w|w|w|_|b|w|'
        ])

        rulebook.invalid_moves[:white].to_a.sort.should == [5, 34]
        rulebook.invalid_moves[:black].to_a.should == [37]
      end

      it "DOES NOT mark the liberty tiles of groups with more than 1 liberty as invalid" do
        rulebook = build_rulebook([
          '|_|b|_|w|w|_|b|',
          '|_|b|b|b|b|b|b|',
          '|_|_|_|_|_|_|_|',
          '|w|w|w|w|_|_|_|',
          '|w|b|b|w|_|b|b|',
          '|w|_|_|w|b|b|_|',
          '|w|w|w|w|b|_|w|'
        ])
        rulebook.invalid_moves[:white].should be_empty
        rulebook.invalid_moves[:black].should be_empty
      end

      it "marks the shared liberty of multiple same-colored single liberty groups as invalid" do
        rulebook = build_rulebook([
          '|b|w|w|w|_|w|b|_|',
          '|b|b|b|b|b|b|b|_|',
          '|_|_|_|_|_|_|_|_|',
          '|w|w|w|w|w|_|_|_|',
          '|w|b|b|b|w|w|w|_|',
          '|_|w|w|_|b|b|w|_|',
          '|_|w|b|b|w|w|w|_|',
          '|_|w|b|w|w|_|_|_|'
        ])
        rulebook.invalid_moves[:white].to_a.should == [4]
        rulebook.invalid_moves[:black].to_a.should == [43]
      end

      it "DOES NOT mark the liberty tile as invalid when it connects friendly group with multiple liberties" do
        rulebook = build_rulebook([
          '|_|w|w|w|_|w|b|_|',
          '|b|b|b|b|b|b|b|_|',
          '|_|_|_|_|_|_|_|_|',
          '|w|w|w|_|w|_|_|_|',
          '|w|b|b|b|w|w|w|_|',
          '|_|w|w|_|b|b|w|_|',
          '|_|w|b|b|w|w|w|_|',
          '|_|w|b|w|w|_|_|_|'
        ])
        rulebook.invalid_moves[:white].should be_empty
        rulebook.invalid_moves[:black].should be_empty
      end
    end
  end

  context "when finding killing moves (rulebook.get_killing_moves)" do

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
  'b' => BLACK,
  'w' => WHITE,
  '_' => GoApp::EMPTY_TILE
}
