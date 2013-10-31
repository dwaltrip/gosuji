module Rulebook

  class Handler
    attr_reader :size, :group_ids, :members, :liberties, :colors, :group_count,
      :invalid_moves, :captured_stones, :ko_position

    EMPTY = GoApp::EMPTY_TILE
    TILE_VALUES = { white: GoApp::WHITE_STONE, black: GoApp::BLACK_STONE }

    TILE_VALUES_REVERSE = {}
    TILE_VALUES.each { |key, val| TILE_VALUES_REVERSE[val] = key }

    def initialize(params = {})
      @size = params[:size]
      @active_player_color = TILE_VALUES[params[:active_player_color]]
      @enemy_color = TILE_VALUES.values.select { |val| val != @active_player_color }.pop
      @board = params[:board]

      @group_ids = {}
      @colors = {}
      @members = Hash.new { |hash, key| hash[key] = Set.new }
      @liberties = Hash.new { |hash, key| hash[key] = Set.new }
      @group_count = 0

      build_groups

      log_info = "active_player= #{TILE_VALUES_REVERSE[@active_player_color].inspect}"
      log_info << ", enemy= #{TILE_VALUES_REVERSE[@enemy_color].inspect}"
      Rails.logger.info "-- Rulebook.initialize (done): #{log_info}"
    end

    def play_move(move_pos)
      Rails.logger.info "-- Rulebook.play_move (entering): move_pos= #{move_pos.inspect}"
      killing_moves = get_killing_moves
      @captured_stones = Set.new

      if killing_moves.key?(move_pos)
        killing_move = move_pos

        captured_groups = killing_moves[killing_move]
        if captured_groups.size == 1
          check_for_ko(killing_move, captured_groups)
        end

        captured_groups.each do |group|
          @captured_stones += @members[group]
          capture_group(group)
        end
      end
    end

    def calculate_invalid_moves
      @invalid_moves = find_invalid_moves
    end


    private

    def find_invalid_moves
      potential_groups = single_liberty_groups.select do |group_id, libs|
        @colors[group_id] == @active_player_color
      end

      killing_moves = get_killing_moves
      invalid_moves = Set.new

      potential_groups.each do |potential_id, libs|
        only_liberty_pos = libs.to_a.pop
        move_would_result_in_zero_libs = true

        unless killing_moves.key?(only_liberty_pos)
          neighbors(only_liberty_pos).each do |neighbor_pos|
            neighbor_id = @group_ids[neighbor_pos]

            # if neighbor_pos is part of a group that isnt current potential group
            if neighbor_id && neighbor_id != potential_id
              same_color = (@colors[neighbor_id] == @active_player_color)
              more_than_one_lib = (@liberties[neighbor_id].size > 1)

              if same_color && more_than_one_lib
                move_would_result_in_zero_libs = false
              end
            # or if there is another empty spot next to the liberty
            elsif @board[neighbor_pos] == EMPTY
              move_would_result_in_zero_libs = false
            end
          end

          if move_would_result_in_zero_libs
            invalid_moves.add(only_liberty_pos)
          end
        end
      end

      @board.each_with_index do |tile_type, pos|
        if tile_type == EMPTY
          neighbor_tiles = neighbor_tile_types(pos)
          enemy_neighbors = neighbor_tiles.count { |tile| tile == @enemy_color }
          completely_surrounded = (enemy_neighbors == neighbor_tiles.size)

          if completely_surrounded && (not killing_moves.key?(pos))
            invalid_moves.add(pos)
          end
        end
      end

      invalid_moves
    end

    def capture_group(group)
      @members[group].each do |captured_pos|
        @group_ids.delete(captured_pos)
      end
      @liberties.delete(group)
      @colors.delete(group)

      @members[group].each do |captured_pos|
        add_as_liberty_to_neighbors(captured_pos)
      end
      @members.delete(group)
    end

    def add_as_liberty_to_neighbors(captured_pos)
      neighbors(captured_pos).each do |pos|
        neighbor_group = @group_ids[pos]
        if neighbor_group
          @liberties[neighbor_group].add(captured_pos)
        end
      end
    end

    def get_killing_moves
      # hash value is a set of group ids, as some moves can kill multiple groups
      killing_moves = Hash.new { |hash, key| hash[key] = Set.new }

      @liberties.each do |group_id, libs|
        if (libs.size == 1) && (@colors[group_id] == @enemy_color)
          killing_move_pos = libs.to_a.pop
          killing_moves[killing_move_pos].add(group_id)
        end
      end

      Rails.logger.info "-- Rulebook.get_killing_moves (done): killing_moves= #{killing_moves.inspect}"
      killing_moves
    end

    def check_for_ko(killing_move, captured_groups)
      captured_group = captured_groups.to_a.pop

      if @members.key?(captured_group) && (@members[captured_group].size == 1)
        captured_stone = @members[captured_group].to_a.pop
        Rails.logger.info "-- Rulebook.check_for_ko: captured_stone= #{captured_group.inspect}"

        killing_stone_is_immediately_recapturable = true

        neighbors(killing_move).each do |neighbor_pos|
          neighbor_group = @group_ids[neighbor_pos]

          is_captured_stone = (captured_stone == neighbor_pos)
          is_enemy_stone = (neighbor_group && (@colors[neighbor_group] == @enemy_color))

          log_msg = "nieghbor_pos= #{neighbor_pos.inspect}"
          log_msg << ", neighbor_group= #{neighbor_group.inspect}"
          log_msg << ", is_captured_stone= #{is_captured_stone.inspect}"
          log_msg << ", is_enemy_stone= #{is_enemy_stone.inspect}"
          Rails.logger.info "-- Rulebook.check_for_ko: #{log_msg}"

          if not (is_captured_stone || is_enemy_stone)
            killing_stone_is_immediately_recapturable = false
          end
        end

        if killing_stone_is_immediately_recapturable
          @ko_position = captured_stone
        end
      end
    end

    def single_liberty_groups
      @liberties.select { |group_id, libs| (libs.size == 1) }
    end

    def build_groups
      @board.each_with_index do |tile_type, pos|
        up, left = up_and_left_neighbors(pos)
        up_group, left_group = get_group_ids(up, left)

        if tile_type == EMPTY
          if left_group
            @liberties[left_group].add(pos)
          end
          if up_group
            @liberties[up_group].add(pos)
          end

        else
          # if same color as left stone, add to that group
          if left && (tile_type == @board[left])
            @members[left_group].add(pos)
            @group_ids[pos] = left_group
          end

          # if same color as up stone, add to that group
          if up && (tile_type == @board[up])

            # check if already added to left group, and if up group is different, then combine the two
            if left_group && @members[left_group].include?(pos) && left_group != up_group
              @members[left_group].each do |left_group_pos|
                @group_ids[left_group_pos] = up_group
              end
              @members[up_group] += @members[left_group]
              @liberties[up_group] += @liberties[left_group]

              # remove prior references to left group
              @members.delete(left_group)
              @liberties.delete(left_group)
              left_group = up_group
            # else just add to up group as usual
            else
              @members[up_group].add(pos)
              @group_ids[pos] = up_group
            end
          end

          if not @group_ids[pos]
            @group_count += 1
            new_group_id = @group_count

            @group_ids[pos] = new_group_id
            @members[new_group_id].add(pos)
            @colors[new_group_id] = tile_type
          end

          # if left or up are empty, add as liberties for current group
          group = @group_ids[pos]
          if up && @board[up] == EMPTY
            @liberties[group].add(up)
          end
          if left && @board[left] == EMPTY
            @liberties[group].add(left)
          end
        end
      end
    end

    def neighbors(pos)
      neighbors_hash(pos).values
    end

    def neighbor_tile_types(pos)
      neighbors_hash(pos).values.map { |pos| @board[pos] }
    end

    def up_and_left_neighbors(pos)
      neighbors = neighbors_hash(pos)
      [neighbors[:up], neighbors[:left]]
    end

    def neighbors_hash(pos)
      neighbors = {}

      if pos % @size != 0
        neighbors[:left] = pos - 1
      end
      if (pos + 1) % @size != 0
        neighbors[:right] = pos + 1
      end
      if pos >= @size
        neighbors[:up] = pos - @size
      end
      if pos < (@size - 1) * @size
        neighbors[:down] = pos + @size
      end

      neighbors
    end

    def get_group_ids(*stone_positions)
      stone_positions.map { |pos| @group_ids[pos] or nil }
    end

  end

end
