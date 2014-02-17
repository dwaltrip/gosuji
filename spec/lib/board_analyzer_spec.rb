require 'spec_helper'
require "#{Rails.root}/lib/scoring"

RSpec.configure do |c|
  c.alias_it_should_behave_like_to :it_
end

BLACK = GoApp::BLACK_STONE
WHITE = GoApp::WHITE_STONE

CHAR_MAP = {
  'b' => BLACK,
  'w' => WHITE,
  '_' => GoApp::EMPTY_TILE
}

def build_board_analyzer(rows)
  board = make_board(rows)
  size = rows[0].gsub('|', '').length

  rows.each_with_index do |row, i|
    raise "Row #{i} has the incorrect number of tiles" if row.gsub('|', '').length != size
  end
  raise "Row inputs do not form a square board" if size**2 != board.length

  Scoring::BoardAnalyzer.new(board: board, size: Integer(size))
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

# single letters to save space
G = Group = Struct.new(:color, :stones, :liberties, :neighbors)
T = Territory = Struct.new(:tiles, :neighbors)
B = BLACK
W = WHITE


describe Scoring::BoardAnalyzer do

  describe ".build_stone_groups_and_territories" do

    # this specific example board was copied from rulebook spec (along with much of the 'expected_groups' data)
    # open ./spec/lib/medium-example-10x10.png for easier human viewing of example board
    board_analyzer = build_board_analyzer([
      '|_|w|_|w|_|b|w|_|b|_|',
      '|w|_|w|w|_|b|b|b|_|b|',
      '|_|w|_|w|b|b|_|_|b|_|',
      '|b|w|_|b|_|w|b|b|b|b|',
      '|w|b|w|b|w|b|_|w|_|b|',
      '|_|b|w|b|w|b|b|b|b|_|',
      '|w|w|w|b|b|_|w|w|w|b|',
      '|b|b|b|_|w|_|w|w|b|_|',
      '|w|_|b|_|w|w|b|w|w|b|',
      '|w|b|_|b|w|b|_|b|w|b|'
    ])

    expected_groups = {
      1  => G.new(W, [1], [0, 2, 11],                                         { enemies: [] }),
      2  => G.new(W, [6], [7],                                                { enemies: [8] }),
      3  => G.new(B, [8], [7, 9, 18],                                         { enemies: [] }),
      4  => G.new(W, [10], [0, 11, 20],                                       { enemies: [] }),
      5  => G.new(W, [12, 13, 3, 23], [2, 11, 4, 14, 22],                     { enemies: [8, 10] }),
      6  => G.new(B, [19], [9, 18, 29],                                       { enemies: [] }),
      7  => G.new(W, [21, 31], [11, 20, 22, 32],                              { enemies: [9, 14] }),
      8  => G.new(B, [24, 25, 5, 15, 16, 17], [14, 4, 7, 18, 26, 27, 34],     { enemies: [2, 5, 11] }),
      9  => G.new(B, [30], [20],                                              { enemies: [7, 13] }),
      10 => G.new(B, [33, 43, 53, 63, 64], [32, 34, 65, 73],                  { enemies: [5, 15, 18, 22] }),
      11 => G.new(W, [35], [34],                                              { enemies: [8, 12, 16] }),
      12 => G.new(B, [36, 37, 38, 28, 39, 49], [26, 27, 18, 29, 46, 48, 59],  { enemies: [11, 17] }),
      13 => G.new(W, [40], [50],                                              { enemies: [9, 14] }),
      14 => G.new(B, [41, 51], [50],                                          { enemies: [7, 13, 18] }),
      15 => G.new(W, [44, 54], [34],                                          { enemies: [10, 16] }),
      16 => G.new(B, [45, 55, 56, 57, 58], [46, 48, 59, 65],                  { enemies: [11, 15, 17, 19] }),
      17 => G.new(W, [47], [46, 48],                                          { enemies: [12, 16] }),
      18 => G.new(W, [60, 61, 62, 42, 52], [50, 32],                          { enemies: [10, 14, 21] }),
      19 => G.new(W, [66, 67, 68, 76, 77, 87, 88, 98], [65, 75],              { enemies: [16, 20, 23, 25, 29, 30] }),
      20 => G.new(B, [69], [59, 79],                                          { enemies: [19] }),
      21 => G.new(B, [70, 71, 72, 82], [73, 81, 83, 92],                      { enemies: [18, 24] }),
      22 => G.new(W, [74, 84, 85, 94], [73, 75, 83],                          { enemies: [10, 25, 27, 28] }),
      23 => G.new(B, [78], [79],                                              { enemies: [19] }),
      24 => G.new(W, [80, 90], [81],                                          { enemies: [21, 26] }),
      25 => G.new(B, [86], [96],                                              { enemies: [19, 22] }),
      26 => G.new(B, [91], [81, 92],                                          { enemies: [24] }),
      27 => G.new(B, [93], [83, 92],                                          { enemies: [22] }),
      28 => G.new(B, [95], [96],                                              { enemies: [22] }),
      29 => G.new(B, [97], [96],                                              { enemies: [19] }),
      30 => G.new(B, [89, 99], [79],                                          { enemies: [19] })
    }

    expected_territories = {
      1  => T.new([0],      { white: [1, 4], black: [] }),
      2  => T.new([2],      { white: [1, 5], black: [] }),
      3  => T.new([4, 14],  { white: [5], black: [8] }),
      4  => T.new([7],      { white: [2], black: [3, 8] }),
      5  => T.new([9],      { white: [], black: [3, 6] }),
      6  => T.new([11],     { white: [1, 4, 5, 7], black: [] }),
      7  => T.new([18],     { white: [], black: [3, 6, 8, 12] }),
      8  => T.new([20],     { white: [4, 7], black: [9] }),
      9  => T.new([22, 32], { white: [5, 7, 18], black: [10] }),
      10 => T.new([26, 27], { white: [], black: [8, 12] }),
      11 => T.new([29],     { white: [], black: [6, 12] }),
      12 => T.new([34],     { white: [11, 15], black: [8, 10] }),
      13 => T.new([46],     { white: [17], black: [12, 16] }),
      14 => T.new([48],     { white: [17], black: [12, 16] }),
      15 => T.new([50],     { white: [13, 18], black: [14] }),
      16 => T.new([59],     { white: [], black: [12, 16, 20] }),
      17 => T.new([65, 75], { white: [19, 22], black: [10, 16] }),
      18 => T.new([73, 83], { white: [22], black: [10, 21, 27] }),
      19 => T.new([79],     { white: [], black: [20, 23, 30] }),
      20 => T.new([81],     { white: [24], black: [21, 26] }),
      21 => T.new([92],     { white: [], black: [21, 26, 27] }),
      23 => T.new([96],     { white: [], black: [25, 28, 29] })
    }

    it "identifies stone groups, and the member stones for each group" do
      expect(board_analyzer.stone_groups.size).to eq(expected_groups.size)

      expected_groups.values.each do |expected_group|
        actual_group = board_analyzer.find_container(expected_group.stones.to_a[0])

        expected_group.stones.each do |stone_pos|
          expect(board_analyzer.find_container(stone_pos)).to eq(actual_group)
        end

        expect(actual_group.stones).to eq(Set.new(expected_group.stones))
      end
    end

    it "identifies the liberties of each group" do
      expected_groups.values.each do |expected_group|
        actual_group = board_analyzer.find_container(expected_group.stones.to_a[0])
        expect(actual_group.liberties).to eq(Set.new(expected_group.liberties))
      end
    end

    it "identifies the neighboring enemy groups for each group" do
      expected_groups.values.each do |expected_group|
        actual_group = board_analyzer.find_container(expected_group.stones.to_a[0])

        expect(actual_group.neighboring_enemy_groups.size).to eq(expected_group.neighbors[:enemies].size)
        expected_group.neighbors[:enemies].each do |neighboring_group_num|

          neighboring_group_first_stone_pos = expected_groups[neighboring_group_num].stones.to_a[0]
          expected_actual_neighboring_group = board_analyzer.find_container(neighboring_group_first_stone_pos)

          expect(actual_group.neighboring_enemy_groups).to include(expected_actual_neighboring_group)
          expect(expected_actual_neighboring_group.neighboring_enemy_groups).to include(actual_group)
        end
      end
    end

    it "labels the color of each group" do
      expected_groups.values.each do |expected_group|
        actual_group = board_analyzer.find_container(expected_group.stones.to_a[0])
        expect(actual_group.color).to eq(expected_group.color)
      end
    end

    it "identifies board territories, and the member tiles for each territory" do
      expect(board_analyzer.territories.size).to eq(expected_territories.size)

      expected_territories.values.each do |expected_territory|
        actual_territory = board_analyzer.find_container(expected_territory.tiles.to_a[0])

        expected_territory.tiles.each do |tile_pos|
          expect(board_analyzer.find_container(tile_pos)).to eq(actual_territory)
        end

        expect(actual_territory.tiles).to eq(Set.new(expected_territory.tiles))
      end
    end

    it "identifies the neighboring stone groups for each territory" do
      expected_territories.values.each do |expected_territory|
        actual_territory = board_analyzer.find_container(expected_territory.tiles.to_a[0])

        [:black, :white].each do |color|
          expect(actual_territory.neighboring_groups(color).size).to eq(expected_territory.neighbors[color].size)

          expected_territory.neighbors[color].each do |neighboring_group_num|
            neighboring_group_first_stone_pos = expected_groups[neighboring_group_num].stones.to_a[0]
            expected_actual_neighboring_group = board_analyzer.find_container(neighboring_group_first_stone_pos)

            expect(actual_territory.neighboring_groups(color)).to include(expected_actual_neighboring_group)
            expect(expected_actual_neighboring_group.neighboring_territories).to include(actual_territory)
          end
        end
      end
    end
  end

  describe ".diagonally_neighboring_tiles" do
    Example = Struct.new(:description, :board_rows, :tiles, :expected_diagonals)

    shared_examples "returns the diagonally neighboring tile positions" do |examples|
      examples.each do |example|
        it "for tiles that are #{example.description}" do
          analyzer = build_board_analyzer(example.board_rows)
          expect(analyzer.diagonally_neighboring_tiles(example.tiles).sort).to eq(example.expected_diagonals.sort)
        end
      end
    end

    context "with a size 1 territory" do
      examples = [
        Example.new("in the center", [
          '|_|b|_|',
          '|b|_|b|',
          '|_|b|_|'], [4], [0, 2, 6, 8]),
        Example.new("on the edge", [
          '|_|b|b|',
          '|_|b|_|',
          '|_|b|b|'], [5], [1, 7]),
        Example.new("in the corner", [
          '|_|_|_|',
          '|b|_|_|',
          '|_|b|b|'], [6], [4])
      ]

      it_ "returns the diagonally neighboring tile positions", examples
    end

    context "with a size 2 territory" do
      examples = [
        Example.new("in the center, vertically aligned", [
          '|_|_|b|_|',
          '|_|b|_|b|',
          '|_|b|_|b|',
          '|_|_|b|_|'], [6, 10], [1, 3, 13, 15]),
        Example.new("in the center, horizontally aligned", [
          '|_|_|_|_|',
          '|_|b|b|b|',
          '|b|_|_|b|',
          '|_|b|b|_|'], [9, 10], [4, 7, 12, 15]),
        Example.new("on the edge, perpendicular to edge", [
          '|_|b|_|b|',
          '|_|b|_|b|',
          '|_|_|b|_|',
          '|_|_|_|_|'], [2, 6], [9, 11]),
        Example.new("on the edge, parallel to edge", [
          '|_|b|_|_|b|',
          '|_|b|b|b|b|',
          '|_|_|_|_|_|',
          '|_|_|_|_|_|',
          '|_|_|_|_|_|'], [2, 3], [6, 9]),
        Example.new("in the corner, vertically aligned", [
          '|_|b|_|_|_|',
          '|_|b|_|_|_|',
          '|b|_|_|_|_|',
          '|_|_|_|_|_|',
          '|_|_|_|_|_|'], [0, 5], [11]),
        Example.new("in the corner, horizontally aligned", [
          '|_|_|_|_|_|',
          '|_|_|_|_|_|',
          '|_|_|_|_|_|',
          '|b|b|_|_|_|',
          '|_|_|b|_|_|'], [20, 21], [17])
      ]

      it_ "returns the diagonally neighboring tile positions", examples
    end
  end

  describe '.determine_and_set_eye_status' do
    Context = Struct.new(:description, :sub_contexts)
    SubContext = Struct.new(:description, :examples)
    Example = Struct.new(:description, :board_rows, :territory_pos, :expected_to_be_eye)

    example_groups = [
      Context.new("size 1 territory", [

        SubContext.new("in the corner", [
          Example.new("with 1 out of 1 digaonals occupied by enemy stones", [
            '|_|b|_|',
            '|_|w|b|',
            '|_|_|_|'], 2, false),
          Example.new("with 0 out of 1 digaonals occupied by enemy stones", [
            '|_|b|_|',
            '|b|b|_|',
            '|_|_|_|'], 0, true)
        ]),
        SubContext.new("on the edge", [
          Example.new("with 2 out of 2 digaonals occupied by enemy stones", [
            '|b|_|_|_|',
            '|b|w|w|_|',
            '|_|b|_|_|',
            '|b|w|w|_|'], 8, false),
          Example.new("with 1 out of 2 digaonals occupied by enemy stones", [
            '|_|_|_|b|',
            '|_|_|b|_|',
            '|_|w|w|b|',
            '|_|_|_|b|'], 7, false),
          Example.new("with 0 out of 2 digaonals occupied by enemy stones", [
            '|_|b|_|b|',
            '|_|b|b|b|',
            '|_|_|_|_|',
            '|_|_|_|_|'], 2, true)
        ]),
        SubContext.new("in the center", [
          Example.new("with 4 out of 4 digaonals occupied by enemy stones", [
            '|_|_|_|_|_|',
            '|_|w|b|w|_|',
            '|_|b|_|b|_|',
            '|_|w|b|w|_|',
            '|_|_|_|_|_|'], 12, false),
          Example.new("with 3 out of 4 digaonals occupied by enemy stones", [
            '|_|b|_|w|_|',
            '|b|b|w|w|w|',
            '|b|_|b|b|_|',
            '|w|b|w|w|w|',
            '|w|w|w|_|_|'], 11, false),
          Example.new("with 2 out of 4 digaonals occupied by enemy stones", [
            '|_|_|_|b|_|',
            '|_|_|_|b|_|',
            '|_|w|w|b|_|',
            '|_|w|b|_|b|',
            '|_|w|w|b|_|'], 18, false),
          Example.new("with 1 out of 4 digaonals occupied by enemy stones", [
            '|_|w|w|b|_|',
            '|w|w|b|_|b|',
            '|_|_|b|b|b|',
            '|w|w|w|b|_|',
            '|_|_|w|b|_|'], 8, true),
          Example.new("with 0 out of 4 digaonals occupied by enemy stones", [
            '|_|w|b|b|_|',
            '|w|w|b|_|b|',
            '|_|_|_|b|_|',
            '|w|w|w|b|_|',
            '|_|_|w|b|_|'], 8, true),
        ])
      ]),

      Context.new("size 2 territory", [

        SubContext.new("in the corner", [
          Example.new("with 1 out of 1 digaonals occupied by enemy stones", [
            '|_|_|b|_|',
            '|b|b|w|_|',
            '|b|_|w|_|',
            '|_|_|_|_|'], 0, true),
          Example.new("with 1 out of 1 digaonals occupied by enemy stones", [
            '|_|_|_|_|',
            '|b|_|_|_|',
            '|b|_|_|_|',
            '|_|b|b|_|'], 12, true)
        ]),
        SubContext.new("on the edge, perpendicular to edge", [
          Example.new("with 2 out of 2 digaonals occupied by enemy stones", [
            '|_|b|_|b|',
            '|_|b|_|b|',
            '|w|w|b|w|',
            '|_|_|b|_|'], 2, true),
          Example.new("with 1 out of 2 digaonals occupied by enemy stones", [
            '|_|w|_|_|',
            '|w|w|b|b|',
            '|_|b|_|_|',
            '|_|_|b|b|'], 10, true),
        ]),
        SubContext.new("on the edge, parallel to edge", [
          Example.new("with 2 out of 2 digaonals occupied by enemy stones", [
            '|_|b|_|_|b|',
            '|_|w|b|b|w|',
            '|_|w|_|_|w|',
            '|_|w|_|w|w|',
            '|_|_|_|_|_|'], 3, false),
          Example.new("with 1 out of 2 digaonals occupied by enemy stones", [
            '|_|b|_|_|b|',
            '|_|w|b|b|_|',
            '|_|w|_|_|_|',
            '|_|w|_|_|_|',
            '|_|_|_|_|_|'], 3, true),
          Example.new("with 0 out of 2 digaonals occupied by enemy stones", [
            '|b|_|_|_|',
            '|_|b|_|_|',
            '|_|b|_|_|',
            '|b|b|_|_|'], 8, true)
        ]),
        SubContext.new("in the center", [
          Example.new("with 4 out of 4 digaonals occupied by enemy stones", [
            '|w|w|w|w|_|',
            '|w|b|b|w|w|',
            '|b|_|_|b|_|',
            '|w|b|b|w|_|',
            '|w|_|_|w|_|'], 12, false),
          Example.new("with 3 out of 4 digaonals occupied by enemy stones", [
            '|_|w|_|w|_|',
            '|w|w|b|w|w|',
            '|_|b|_|b|w|',
            '|_|b|_|b|w|',
            '|_|_|b|w|w|'], 17, true),
          Example.new("with 2 out of 4 digaonals occupied by enemy stones", [
            '|_|_|_|_|_|',
            '|w|w|w|w|_|',
            '|w|b|b|w|_|',
            '|b|_|_|b|_|',
            '|b|b|b|_|_|'], 16, true),
          Example.new("with 1 out of 4 digaonals occupied by enemy stones", [
            '|_|w|b|b|_|',
            '|w|w|b|_|b|',
            '|_|_|b|_|b|',
            '|w|w|_|b|w|',
            '|_|w|w|w|w|'], 8, true)
        ])
      ])
    ]

    # static structure: array of contexts -> array of sub-contexts -> array of examples
    example_groups.each do |current_context|
      context "sets eye status of #{current_context.description}" do

        current_context.sub_contexts.each do |sub_context|
          context sub_context.description do

            sub_context.examples.each do |example|
              eye_status = "%s, %s an eye" % [
                example.expected_to_be_eye.to_s.upcase,
                (("is" if example.expected_to_be_eye) || "NOT")
              ]

              it "#{example.description} as: #{eye_status}" do
                board_analyzer = build_board_analyzer(example.board_rows)
                territory = board_analyzer.find_container(example.territory_pos)
                board_analyzer.determine_and_set_eye_status(territory)

                expect(territory.is_eye?).to eq(example.expected_to_be_eye)
              end
            end

          end
        end

      end
    end
  end

  describe '.combine_stone_groups_into_chains' do

    context "with example #1" do
      board_analyzer = build_board_analyzer([
        '|_|w|b|w|b|b|_|',
        '|w|_|b|w|b|_|b|',
        '|w|w|b|w|_|b|b|',
        '|b|b|w|w|w|w|w|',
        '|b|_|b|b|_|w|_|',
        '|_|b|_|b|w|_|w|',
        '|_|_|_|b|w|w|_|'
      ])
      finder = Proc.new { |k| board_analyzer.find_container(k) }

      expected_groups = {
        1   => Group.new(WHITE, [1], [0, 8], { enemies: [2] }),
        2   => Group.new(BLACK, [2, 9, 16], [8], { enemies: [1, 3, 5] }),
        3   => Group.new(WHITE, [3, 10, 17, 23, 24, 25, 26, 27, 33], [18, 32, 34, 40], { enemies: [2, 4, 6, 7, 8] }),
        4   => Group.new(BLACK, [4, 5, 11], [6, 12, 18], { enemies: [3] }),
        5   => Group.new(WHITE, [7, 14, 15], [0, 8], { enemies: [2, 7] }),
        6   => Group.new(BLACK, [13, 19, 20], [6, 12, 18], { enemies: [3] }),
        7   => Group.new(BLACK, [21, 22, 28], [29, 35], { enemies: [3, 5] }),
        8   => Group.new(BLACK, [30, 31, 38, 45], [29, 32, 37, 44], { enemies: [3, 10] }),
        9   => Group.new(BLACK, [36], [29, 35, 37, 43], { enemies: [] }),
        10  => Group.new(WHITE, [39, 46, 47], [32, 40, 48], { enemies: [8] }),
        11  => Group.new(WHITE, [41], [34, 40, 48], { enemies: [] })
      }

      expected_territories = {
        1   => Territory.new([0], { white: [1, 5], black: [] }),
        2   => Territory.new([6], { white: [], black: [4, 6] }),
        3   => Territory.new([8], { white: [1, 5], black: [2] }),
        4   => Territory.new([12], { white: [], black: [4, 6] }),
        5   => Territory.new([18], { white: [3], black: [4, 6] }),
        6   => Territory.new([29], { white: [], black: [7, 8, 9] }),
        7   => Territory.new([32], { white: [3, 10], black: [8] }),
        8   => Territory.new([34], { white: [3, 11], black: [] }),
        9   => Territory.new([35, 37, 42, 43, 44], { white: [], black: [7, 8, 9] }),
        10  => Territory.new([40], { white: [3, 10, 11], black: [] }),
        11  => Territory.new([48], { white: [10, 11], black: [] })
      }

      Chain = Struct.new(:color, :groups, :neighbor_chains, :surrounded_territories, :neutral_territories)
      expected_chains = {
        1 => Chain.new(WHITE, [1, 5], [2, 5], [1], [3]),
        2 => Chain.new(BLACK, [2], [1, 3], [], [3]),
        3 => Chain.new(WHITE, [3, 10, 11], [2, 4, 5], [8, 10, 11], [5, 7]),
        4 => Chain.new(BLACK, [4, 6], [3], [2, 4], [5]),
        5 => Chain.new(BLACK, [7, 8, 9], [1, 3], [6, 9], [7])
      }

      it "identifies chains, and the member stone groups for each chain" do
        expect(board_analyzer.chains.size).to eq(expected_chains.size)

        expected_chains.values.each do |expected_chain|
          # tile position of stone -> StoneGroup instance -> Chain instance
          actual_chain = finder.call(finder.call(expected_groups[expected_chain.groups[0]].stones[0]))

          expect(actual_chain.size).to eq(expected_chain.groups.size)

          expected_chain.groups do |expected_group_id|
            expected_member_group = finder.call(expected_groups[expected_group_id].stones[0])

            expect(actual_chain.groups).to include(expected_member_group)
            expect(actual_chain).to eq(finder.call(expected_actual_group))
          end
        end
      end

      it "identifies neighboring enemy chains" do
        expected_chains.values.each do |expected_chain|
          actual_chain = finder.call(finder.call(expected_groups[expected_chain.groups[0]].stones[0]))

          expect(actual_chain.neighboring_enemy_chains.size).to eq(expected_chain.neighbor_chains.size)

          expected_chain.neighbor_chains do |expected_enemy_chain_id|
            expected_enemy_chain = expected_chains[expected_enemy_chain_id]
            expected_actual_enemy_chain = finder.call(finder.call(expected_enemy_chain.groups[0].stones[0]))

            expect(actual_chain.neighboring_enemy_chains).to include(expected_actual_enemy_chain)
            expect(expected_actual_enemy_chain.neighboring_enemy_chains).to include(actual_chain)
          end
        end
      end

      it "identifes neighboring territories" do
        expected_chains.values.each do |expected_chain|
          actual_chain = finder.call(finder.call(expected_groups[expected_chain.groups[0]].stones[0]))

          expect(actual_chain.surrounded_territories.size).to eq(expected_chain.surrounded_territories.size)
          expect(actual_chain.neutral_territories.size).to eq(expected_chain.neutral_territories.size)

          expected_chain.surrounded_territories.each do |expected_territory_id|
            actual_expected_territory = finder.call(expected_territories[expected_territory_id].tiles[0])
            expect(actual_chain.surrounded_territories).to include(actual_expected_territory)
          end

          expected_chain.neutral_territories.each do |expected_territory_id|
            actual_expected_territory = finder.call(expected_territories[expected_territory_id].tiles[0])
            expect(actual_chain.neutral_territories).to include(actual_expected_territory)
          end
        end
      end
    end

    shared_examples "prepares scoring related chain data" do |board_analyzer, chain_data|
      make_chain = Proc.new do |stone_pos, alive_status, territory_points, eye_pos_list, fake_eye_pos_list|
        OpenStruct.new(
          pos_of_a_member_stone: stone_pos,
          alive_status: alive_status,
          territory_points: territory_points,
          tile_positions_for_eyes: eye_pos_list,
          tile_positions_for_fake_eyes: fake_eye_pos_list
        )
      end
      finder = Proc.new { |k| board_analyzer.find_container(k) }
      expected_chains = chain_data.map { |data| make_chain.call(*data) }

      it "marks which surrounded territories are eyes" do
        expected_chains.each do |expected_chain|
          # tile pos of stone -> StoneGroup instance -> Chain instance
          actual_chain = finder.call(finder.call(expected_chain.pos_of_a_member_stone))

          expected_chain.tile_positions_for_eyes.each do |tile_pos|
            territory = finder.call(tile_pos)

            expect(actual_chain.surrounded_territories).to include(territory)
            expect(actual_chain.has_eye?(territory)).to be_true
            expect(territory.is_eye?).to be_true
          end

          expected_chain.tile_positions_for_fake_eyes.each do |tile_pos|
            territory = finder.call(tile_pos)

            expect(actual_chain.surrounded_territories).to include(territory)
            expect(actual_chain.has_eye?(territory)).to be_false
            expect(territory.is_eye?).to be_false
          end
        end
      end

      it "labels chains as dead or alive" do
        expected_chains.each do |expected_chain|
          # tile pos of stone -> StoneGroup instance -> Chain instance
          actual_chain = finder.call(finder.call(expected_chain.pos_of_a_member_stone))
          expect(actual_chain.alive?).to eq(expected_chain.alive_status)
        end
      end

      it "computes territory points for each chain" do
        expected_chains.each do |expected_chain|
          # tile pos of stone -> StoneGroup instance -> Chain instance
          actual_chain = finder.call(finder.call(expected_chain.pos_of_a_member_stone))
          expect(actual_chain.territory_points).to eq(expected_chain.territory_points)
        end
      end
    end

    context "with example #2" do
      board_analyzer = build_board_analyzer([
        '|_|_|b|b|b|_|b|',
        '|_|b|b|w|w|b|b|',
        '|b|_|w|_|_|w|_|',
        '|b|b|b|w|w|b|b|',
        '|w|w|b|b|w|w|b|',
        '|_|w|w|w|w|b|b|',
        '|w|_|b|_|w|b|_|'
      ])

      data_for_expected_chains = [
        [3,  true,   5, [0, 48], [5]],
        [28, false,  0, [35],    [17, 18]],
        [44, false,  0, [],      []]
      ]

      it_ "prepares scoring related chain data", board_analyzer, data_for_expected_chains
    end

    context "with example #3" do
      board_analyzer = build_board_analyzer([
        '|_|b|w|w|_|w|w|b|_|',
        '|b|_|b|w|w|_|w|b|b|',
        '|w|b|b|w|_|_|w|w|b|',
        '|w|w|b|b|w|w|b|b|_|',
        '|_|w|w|b|b|_|b|b|b|',
        '|w|w|_|w|b|_|b|w|w|',
        '|b|b|w|w|w|w|w|_|w|',
        '|_|b|w|_|b|b|b|w|_|',
        '|b|_|b|b|b|_|b|w|_|',
      ])

      data_for_expected_chains = [
        [1,  true, 4, [0, 8],          [10, 35]],
        [18, true, 9, [4, 22, 36, 80], [47, 61]],
        [72, true, 3, [63, 77],        [73]]
      ]

      it_ "prepares scoring related chain data", board_analyzer, data_for_expected_chains
    end
  end

end

