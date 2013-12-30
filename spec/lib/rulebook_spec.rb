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

  match_for_should do |actual|
    expected_elements.subset? actual.to_set
  end

  match_for_should_not do |actual|
    expected_elements.intersection(actual.to_set).empty?
  end
end

RSpec::Matchers.define :contain_any do |*args|
  expected_elements = args_to_set(args)

  match do |actual|
    expected_elements.intersection(actual.to_set).size > 0
  end

  match_for_should_not do |actual|
    expected_elements.intersection(actual.to_set).empty?
  end
end

RSpec::Matchers.define :contain_exactly do |*args|
  expected_elements = args_to_set(args)

  match do |actual|
    expected_elements == actual.to_set
  end
end

WHITE = GoApp::WHITE_STONE
BLACK = GoApp::BLACK_STONE

CHAR_MAP = {
  'b' => BLACK,
  'w' => WHITE,
  '_' => GoApp::EMPTY_TILE
}
TILE_VAL_TO_SYM = {
  BLACK => :black,
  WHITE => :white,
  GoApp::EMPTY_TILE => :empty
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

def generate_blank_rulebook(size)
  board = Array.new(size**2) { GoApp::EMPTY_TILE }
  Rulebook::Handler.new(board: board, size: size)
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

Scenario = Struct.new(:description, :expected_tiles)
Group = Struct.new(:color, :members, :liberties)

def get_liberties(pos, size)
  libs = []
  libs << pos - 1 if pos % size != 0
  libs << pos + 1 if (pos + 1) % size != 0
  libs << pos + size if pos < (size - 1) * size
  libs << pos - size if pos >= size
  libs.to_set
end


describe Rulebook do

  # Ironically, after realizing 'get_killing_moves' is a private method and cant be cleanly tested
  # I remembered that the only reason the @members, @group_ids, @liberties, and @colors variables are accessible
  # is because I made them accessible while I writing the rulebook code, for testing/debugging purposes
  # so honestly they should be private implementation details that arent cleanly testable
  # alternatively, a superior design would be to extract this data/functionality into Group & GroupManager objects
  # I could then cleanly test the public methods and data on those objects
  # this would be a fair amount of work. but the rulebook class is also unambiguously too large
  shared_examples "properly identifies/maintians board state and stone groups" do |rulebook, expected_groups|

    it "internally maintains correct board state" do
      expected_groups.each do |expected_group|
        expected_group.members.each do |stone_pos|
          expect(rulebook.board[stone_pos]).to eq(expected_group.color)
        end
      end

      expected_stone_count = expected_groups.inject(0) { |sum, group| sum + group.members.size }
      expected_blank_tile_count = (rulebook.size ** 2 - expected_stone_count)
      actual_blank_tile_count = rulebook.board.count { |tile| tile == GoApp::EMPTY_TILE }

      expect(actual_blank_tile_count).to eq(expected_blank_tile_count)
    end

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


  shared_examples "marks as invalid" do |scenarios, rulebook, move_tracker|
    scenarios.each do |scenario|
      it "#{scenario.description}" do
        # keep track of all the expected invalid moves (from each scenario/example)
        # so we can ensure that, together, our specified scenarios equal the set of all invalid moves
        move_tracker.merge(scenario.expected_tiles) unless move_tracker.nil?

        expect(rulebook.invalid_moves[:black]).to contain(scenario.expected_tiles[:black])
        expect(rulebook.invalid_moves[:white]).to contain(scenario.expected_tiles[:white])
      end
    end
  end

  shared_examples "does not mark as invalid" do |scenarios, rulebook|
    scenarios.each do |scenario|
      it "#{scenario.description}" do
        expect(rulebook.invalid_moves[:black]).not_to contain(scenario.expected_tiles[:black])
        expect(rulebook.invalid_moves[:white]).not_to contain(scenario.expected_tiles[:white])
      end
    end
  end

  shared_examples "identifies invalid tiles (rulebook.invalid_moves)" do |rulebook, invalid_tiles, valid_tiles|
    move_tracker = MoveTracker.new

    # block starting with: all_liberties.each do |empty_pos|
    context "examines empty tiles surrounded by stones of a single color" do

      it_ "marks as invalid", [
        Scenario.new("isolated corner tiles", invalid_tiles[:isolated_corners]),
        Scenario.new("isolated edge tiles", invalid_tiles[:isolated_edges]),
        Scenario.new("isolated center tiles", invalid_tiles[:isolated_centers])
      ], rulebook, move_tracker

      it_ "does not mark as invalid", [
        Scenario.new("isolated tile groups of size 2 or more", valid_tiles[:isolated_2_or_more])
      ], rulebook
    end

    # block starting with: single_liberty_groups.each do |single_lib_group_id, libs|
    context "examines stone groups with a single liberty (that are non-killing moves)" do

      it_ "marks as invalid", [
        Scenario.new("the only liberty tile", invalid_tiles[:surrounded_last_lib]),
        Scenario.new("the shared liberty of friendly single-lib groups", invalid_tiles[:shared_single_lib])
      ], rulebook, move_tracker

      it_ "does not mark as invalid", [
        Scenario.new("liberty tiles of surround groups with multiple liberties", valid_tiles[:at_least_2_libs]),
        Scenario.new("liberty tile when conecting to multiple-lib friendly group", valid_tiles[:connect_friendly])
      ], rulebook
    end

    # this last block is dependent on the previous blocks passing successfully
    context "and lastly" do
      # move_tracker object stores invalid moves as it tests them in each shared example/scenario above
      it "exactly matches the combined invalid move set of the specified examples" do
        expect(rulebook.invalid_moves[:black]).to contain_exactly(move_tracker.black)
        expect(rulebook.invalid_moves[:white]).to contain_exactly(move_tracker.white)
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

    invalid_tiles = {
      isolated_corners: { black: [0], white: [9] },
      isolated_edges: { black: [2], white: [29, 92] },
      isolated_centers: { black: [11], white: [18] },
      surrounded_last_lib: { black: [20, 97], white: [7, 81] },
      shared_single_lib: { black: [79], white: [34] }
    }
    valid_tiles = {
      isolated_2_or_more: { black: [], white: [26, 26] },
      at_least_2_libs: { black: [], white: [46, 48, 73, 83] },
      connect_friendly: { black: [], white: [] }
    }

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

    it_ "properly identifies/maintians board state and stone groups", rulebook, expected_groups
    it_ "identifies invalid tiles (rulebook.invalid_moves)", rulebook, invalid_tiles, valid_tiles
  end

  # as I write the code for this section of the specs
  # I realize I should have something like a BoardManager object
  # that can add stones, fetch liberties, knows (and hides from public viewing) the coordinate system, etc
  # this would be tested separately, and then in here I would do things like
  # bm = BoardManager.new(size)
  # bm.add_pos(:white, 1, 1) # this would handle liberties, etc
  # of course, we would first need Group & GroupManager objects, which BoardManager would coordinate with
  context "when handling new moves (rulebook.play_move), basic scenarios" do
    size = 10

    context 'with a blank board' do
      blank_rulebook = generate_blank_rulebook(size)
      expected_groups = []

      it_ "properly identifies/maintians board state and stone groups", blank_rulebook, expected_groups

      moves = {
        center: { black: size + 1, white: (size * 2) - 2 },
        edge: { black: size * 3, white: (size * 4) - 1 },
        corner: { black: (size - 1) * size, white: size**2 - 1 }
      }

      # if we dont wrap setup code in before(:all), then we are testing the final state multiple times
      # instead of testing the rulebook after each move (as we iterate to the final state)
      moves.keys.each do |move_type|
        context "after playing isolated #{move_type} moves" do

          before(:all) do
            [BLACK, WHITE].each do |color|
              # rulebook.play_move accepts ':white' and ':black', while BLACK=false & WHITE=true (db values)
              color_sym = TILE_VAL_TO_SYM[color]
              pos = moves[move_type][color_sym]
              expected_groups << Group.new(color, Set.new([pos]), get_liberties(pos, size))

              blank_rulebook.play_move(pos, color_sym)
            end
          end

          it_ "properly identifies/maintians board state and stone groups", blank_rulebook, expected_groups
        end
      end
    end

    # the sub-sections for this group are not independent. probably not optimal, but fine for now
    # had to add 'before(:all)' blocks, or all the setup code would run before any of the specs were run
    context "after playing stones next to existing groups" do
      small_rulebook = build_rulebook([
        '|_|_|_|_|',
        '|w|_|_|b|',
        '|_|_|_|_|',
        '|_|_|_|_|'
      ])
      expected_groups = []

      context "by adding new stones next to friendly groups" do
        before(:all) do
          expected_groups << Group.new(BLACK, Set.new([7, 11]), Set.new([3, 6, 10, 15]))
          expected_groups << Group.new(WHITE, Set.new([4, 5]), Set.new([0, 1, 6, 8, 9]))

          small_rulebook.play_move(11, :black)
          small_rulebook.play_move(5, :white)
        end

        it_ "properly identifies/maintians board state and stone groups", small_rulebook, expected_groups
        it_ "marks as invalid", [Scenario.new("no tiles", black: [], white: [])], small_rulebook
      end

      context "by adding new stones next to enemy groups" do
        new_groups = [
          Group.new(BLACK, Set.new([1]), Set.new([0, 2])),
          Group.new(WHITE, Set.new([10]), Set.new([6, 9, 14]))
        ]
        before(:all) do
          expected_groups.each do |old_group|
            new_groups.each { |group| old_group.liberties.subtract(group.members) }
          end
          expected_groups.concat(new_groups)

          small_rulebook.play_move(1, :black)
          small_rulebook.play_move(10, :white)
        end

        it_ "properly identifies/maintians board state and stone groups", small_rulebook, expected_groups
        it_ "marks as invalid", [Scenario.new("no tiles", black: [], white: [])], small_rulebook
      end

      context "which connect two friendly groups" do
        # asterisk is connecting move (top is black, 3rd row is white)
        #        |_|b|_|_|        |_|b|*|b|
        # before |w|w|_|b| after  |w|w|_|b|
        #        |_|_|w|b| -----> |_|*|w|b|
        #        |_|_|_|_|        |_|w|_|_|

        updated_groups = [
          Group.new(BLACK, Set.new([1, 2, 3, 7, 11]), Set.new([0, 6, 15])),
          Group.new(WHITE, Set.new([4, 5, 9, 10, 13]), Set.new([0, 6, 8, 12, 14]))
        ]
        before(:all) do
          small_rulebook.play_move(3, :black)
          small_rulebook.play_move(13, :white)
          small_rulebook.play_move(2, :black)
          small_rulebook.play_move(9, :white)
        end

        it_ "properly identifies/maintians board state and stone groups", small_rulebook, updated_groups
        it_ "marks as invalid", [Scenario.new("no tiles", black: [], white: [])], small_rulebook
      end
    end
  end

end

