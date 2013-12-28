## ---------------------------------------------------------------
## these specs should be run with the flag: --format documentation
## ---------------------------------------------------------------
require 'spec_helper'

RSpec.configure do |c|
  c.alias_it_should_behave_like_to :it_
end

def args_to_set(args)
  if args.length == 1 && args[0].respond_to?(:include?)
    Set.new(args[0])
  else
    Set.new(args)
  end
end

require 'rspec/expectations'
RSpec::Matchers.define :contain do |*args|
  expected_elements = args_to_set(args)

  match do |test_collection|
    expected_elements.subset? test_collection.to_set
  end
end
RSpec::Matchers.define :contain_any do |*args|
  expected_elements = args_to_set(args)

  match do |test_collection|
    expected_elements.intersection(test_collection.to_set).size > 0
  end
end

WHITE = GoApp::WHITE_STONE
BLACK = GoApp::BLACK_STONE
Group = Struct.new(:color, :members, :liberties)

CHAR_MAP = {
  'b' => BLACK,
  'w' => WHITE,
  '_' => GoApp::EMPTY_TILE
}

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

class MoveTracker
  attr_reader :black, :white

  def initialize
    @black = Set.new
    @white = Set.new
  end

  def merge(new_tiles)
    @black.merge(new_tiles[:black])
    @white.merge(new_tiles[:white])
  end
end


describe Rulebook do

  shared_examples "properly identifies stone groups (rulebook.analyze_board)" do |rulebook, expected_groups|

    it "identifies the correct members for each group of stones" do
      expect(rulebook.members.size).to eq(expected_groups.size)

      expected_groups.each do |expected_group|
        random_group_member = expected_group.members.to_a.pop
        group_id = rulebook.group_ids[random_group_member]

        expected_group.members.each do |stone_pos|
          expect(rulebook.group_ids[stone_pos]).to eq(group_id)
        end

        expect(rulebook.members[group_id]).to eq(expected_group.members)
      end
    end

    it "assigns correct liberties for each group" do
      expect(rulebook.liberties.size).to eq(expected_groups.size)

      expected_groups.each do |expected_group|
        group_id = rulebook.group_ids[expected_group.members.to_a.pop]
        expect(rulebook.liberties[group_id]).to eq(expected_group.liberties)
      end
    end

    it "assigns the correct color for each group" do
      expect(rulebook.colors.size).to eq(expected_groups.size)

      expected_groups.each do |expected_group|
        group_id = rulebook.group_ids[expected_group.members.to_a.pop]
        expect(rulebook.colors[group_id]).to eq(expected_group.color)
      end
    end
  end


  context "with a medium sized example" do
    # open ./spec/lib/medium-example-10x10.png for easier human viewing of example board
    rulebook = build_rulebook([
      '|_|w|_|w|_|b|w|_|b|_|',
      '|w|_|w|w|_|b|b|b|_|b|',
      '|_|w|_|w|b|b|_|_|b|_|',
      '|b|w|_|b|_|w|b|b|b|b|',
      '|w|b|w|b|w|b|_|w|_|b|',
      '|_|b|w|b|w|b|b|b|b|_|',
      '|w|w|w|b|b|b|w|w|w|w|',
      '|b|b|b|_|w|w|b|w|b|_|',
      '|w|_|b|_|w|w|b|w|w|b|',
      '|w|b|_|b|w|b|b|_|w|b|'
    ])

    expected_groups = [
      Group.new(WHITE, Set.new([1]), Set.new([0, 2, 11])),
      Group.new(WHITE, Set.new([6]), Set.new([7])),
      Group.new(BLACK, Set.new([8]), Set.new([7, 9, 18])),
      Group.new(WHITE, Set.new([10]), Set.new([0, 11, 20])),
      Group.new(WHITE, Set.new([12, 13, 3, 23]), Set.new([2, 11, 4, 14, 22])),
      Group.new(BLACK, Set.new([19]), Set.new([9, 18, 29])),
      Group.new(WHITE, Set.new([21, 31]), Set.new([11, 20, 22, 32])),
      Group.new(BLACK, Set.new([24, 25, 5, 15, 16, 17]), Set.new([14, 4, 7, 18, 26, 27, 34])),
      Group.new(BLACK, Set.new([30]), Set.new([20])),
      Group.new(BLACK, Set.new([33, 43, 45, 53, 55, 56, 57, 58, 63, 64, 65]), Set.new([32, 34, 46, 48, 59, 73])),
      Group.new(WHITE, Set.new([35]), Set.new([34])),
      Group.new(BLACK, Set.new([36, 37, 38, 28, 39, 49]), Set.new([26, 27, 18, 29, 46, 48, 59])),
      Group.new(WHITE, Set.new([40]), Set.new([50])),
      Group.new(BLACK, Set.new([41, 51]), Set.new([50])),
      Group.new(WHITE, Set.new([44, 54]), Set.new([34])),
      Group.new(WHITE, Set.new([47]), Set.new([46, 48])),
      Group.new(WHITE, Set.new([60, 61, 62, 42, 52]), Set.new([50, 32])),
      Group.new(WHITE, Set.new([66, 67, 68, 69, 77, 87, 88, 98]), Set.new([59, 79, 97])),
      Group.new(BLACK, Set.new([70, 71, 72, 82]), Set.new([73, 81, 83, 92])),
      Group.new(WHITE, Set.new([74, 75, 84, 85, 94]), Set.new([73, 83])),
      Group.new(BLACK, Set.new([78]), Set.new([79])),
      Group.new(WHITE, Set.new([80, 90]), Set.new([81])),
      Group.new(BLACK, Set.new([91]), Set.new([81, 92])),
      Group.new(BLACK, Set.new([93]), Set.new([83, 92])),
      Group.new(BLACK, Set.new([89, 99]), Set.new([79])),
      Group.new(BLACK, Set.new([95, 96, 76, 86]), Set.new([97])),
    ]
    move_tracker = MoveTracker.new

    it_ "properly identifies stone groups (rulebook.analyze_board)", rulebook, expected_groups

    context "when marking invalid moves (rulebook.invalid_moves)" do
      Scenario = Struct.new(:description, :expected_tiles)

      shared_examples "marks" do |scenarios|
        scenarios.each do |scenario|
          it "#{scenario.description} as invalid" do
            # keep track of all the expected invalid moves (from each scenario/example)
            # so we can ensure that, together, our specified scenarios equal the set of all invalid moves
            move_tracker.merge(scenario.expected_tiles)

            expect(rulebook.invalid_moves[:black]).to contain(scenario.expected_tiles[:black])
            expect(rulebook.invalid_moves[:white]).to contain(scenario.expected_tiles[:white])
          end
        end
      end

      # block starting with: all_liberties.each do |empty_pos|
      context "and examining empty tiles surrounded by stones of a single color" do

        it_ "marks", [
          Scenario.new("isolated corner tiles", black: [0], white: [9]),
          Scenario.new("isolated edge tiles", black: [2], white: [29, 92]),
          Scenario.new("isolated center tiles", black: [11], white: [18])
        ]

        it "does not mark tile groups of size 2 (or more) as invalid" do
          expect(rulebook.invalid_moves[:white]).not_to contain_any(26, 27)
        end
      end

      # block starting with: single_liberty_groups.each do |single_lib_group_id, libs|
      context "and examining stone groups with a single liberty (that are non-killing moves)" do

        it_ "marks", [
          Scenario.new("the liberty tile", black: [20, 97], white: [7, 81]),
          Scenario.new("the shared liberty of friendly single liberty groups", black: [79], white: [34])
        ]

        it "does not mark the liberty tiles of surrounded groups with more than 1 liberty as invalid" do
          expect(rulebook.invalid_moves[:white]).not_to contain_any(46, 48, 73, 83)
        end

        # medium example does not have this scenario
        #it "does not mark the liberty tile as invalid when it connects to a friendly group w/ multiple liberties" do
        #  expect(rulebook.invalid_moves[:white]).not_to contain_any(...)
        #end
      end

      context "and lastly" do
        # invalid_moves object stores the moves as it tests them in each example above (for this test)
        it "exactly matches the combined invalid move set of the specified examples" do
          expect(rulebook.invalid_moves[:black]).to eq(move_tracker.black)
          expect(rulebook.invalid_moves[:white]).to eq(move_tracker.white)
        end
      end
    end

    context "when finding killing moves (rulebook.get_killing_moves)" do

    end
  end
end
