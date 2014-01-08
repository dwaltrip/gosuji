module Rulebook

  class Handler
    attr_reader :size, :group_ids, :members, :liberties, :colors, :group_count, :captured_stones
    attr_reader :_ko_position, :board

    EMPTY = GoApp::EMPTY_TILE
    TILE_VALUES = { white: GoApp::WHITE_STONE, black: GoApp::BLACK_STONE }

    TILE_VALUES_REVERSE = {}
    TILE_VALUES.each { |key, val| TILE_VALUES_REVERSE[val] = key }

    def initialize(params = {})
      @size = params[:size]
      @board = params[:board]
      @verbose = params[:verbose] || false

      analyze_board

      Rails.logger.info "-- Rulebook.initialize -- done"
    end

    def playable?(move_pos, player_color)
      true
    end

    def play_move(move_pos, player_color)
      Rails.logger.info "-- Rulebook.play_move -- move_pos= #{move_pos.inspect}"
      set_player_colors(player_color)

      if @_ko_position
        @former_ko_position = @_ko_position.dup
        remove_instance_variable(:@_ko_position)
      end

      killing_moves = get_killing_moves()[@active_player_color]
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

      @board[move_pos] = @active_player_color

      if @captured_stones && (@captured_stones.size > 0)
        # could potentially create a method that updates only relevant sections of board after a capture
        # but would be complex, right now we simply recreate board analysis after capturing stones
        analyze_board

        # format of @new_killing_moves is simpler than that returned by get_killing_moves method
        # we only care about the positions (the keys), and can discard lists of groups that each move kills (values)
        _killing_moves = get_killing_moves
        @new_killing_moves = {
          @active_player_color => _killing_moves[@active_player_color].keys,
          @enemy_color => _killing_moves[@enemy_color].keys
        }

        # if a group has two or more libs, and all but one of the libs are brand new from the captured group
        # then that means this lib is no longer an invalid move for the group owner
        @former_invalid_moves = { @active_player_color => Set.new, @enemy_color => Set.new }
        Rails.logger.info "-- Rulebook.play_move -- @captured_stones: #{@captured_stones.inspect}"

        (@liberties.select { |group_id, libs| libs.size > 1 }).each do |group_id, libs|
          @remaining_libs = libs.difference(@captured_stones)
          if @remaining_libs.size == 1
            @former_invalid_moves[@colors[group_id]].add @remaining_libs.to_a.pop
          end
        end

      # if no captured stones, then updating is much simpler
      else
        @new_killing_moves = { @active_player_color => Set.new, @enemy_color => Set.new }
        update_neighbors(move_pos, @active_player_color)
      end
      @active_player_color, @enemy_color = @enemy_color, @active_player_color
      @new_move_pos = move_pos

      Rails.logger.info "-- Rulebook.play_move -- @former_invalid_moves: #{@former_invalid_moves.inspect}"
      Rails.logger.info "-- Rulebook.play_move -- @new_killing_moves: #{@new_killing_moves.inspect}"

      invalid_moves(force_recalculate=true)
      Rails.logger.info "-- Rulebook.play_move -- invalid_moves: #{invalid_moves.inspect}"
    end

    def tiles_to_update(player_color)
      color = TILE_VALUES[player_color]

      tiles = Set.new
      tiles.merge(@new_killing_moves[color]) if @new_killing_moves
      tiles.merge(invalid_moves[player_color])
      tiles.merge(@captured_stones) if @captured_stones
      tiles.merge(@former_invalid_moves[color]) if @former_invalid_moves
      tiles.add(@_ko_position[color]) if @_ko_position && @_ko_position[color]
      tiles.add(@former_ko_position[color]) if @former_ko_position && @former_ko_position[color]
      tiles.add(@new_move_pos)

      tiles
    end

    def invalid_moves(force_recalculate=false)
      if not (instance_variable_defined?("@active_player_color") && instance_variable_defined?("@enemy_color"))
        # for this, it does not matter who is active player
        # as 'ko_position' should already be set, if necessary
        set_player_colors(:white)
      end

      if force_recalculate
        @_invalid_moves = calculate_invalid_moves
      else
        @_invalid_moves ||= calculate_invalid_moves
      end
    end

    def ko_position(player_color=nil)
      if @_ko_position
        if player_color == nil
          @_ko_position
        else
          @_ko_position[TILE_VALUES[player_color]]
        end
      end
    end

    def set_ko_position(ko_pos, player_color)
      @_ko_position = { TILE_VALUES[player_color] => ko_pos }
    end

    private

    def analyze_board
      Rails.logger.info "-- Rulebook.analyze_board --"
      @group_ids = {}
      @colors = {}
      @members = Hash.new { |hash, key| hash[key] = Set.new }
      @liberties = Hash.new { |hash, key| hash[key] = Set.new }
      @group_count = 0

      build_groups

      if @verbose
        Rails.logger.info "-- Rulebook.analyze_board -- @colors, @members"
        @members.keys.sort.each do |group_id|
          Rails.logger.info "\t#{group_id.inspect}=>#{@colors[group_id].inspect}, #{@members[group_id].inspect}"
        end
        Rails.logger.info "-- Rulebook.analyze_board -- @liberties"
        @liberties.keys.sort.each do |group_id|
          Rails.logger.info "\t#{group_id.inspect}=>#{@liberties[group_id].inspect}"
        end
      end
    end

    def set_player_colors(active_player_color)
      @active_player_color = TILE_VALUES[active_player_color]
      @enemy_color = opposing_color(@active_player_color)

      log_info = "active_player= #{TILE_VALUES_REVERSE[@active_player_color].inspect}"
      log_info << ", enemy= #{TILE_VALUES_REVERSE[@enemy_color].inspect}"
      Rails.logger.info "-- Rulebook.set_player_colors -- #{log_info}"
    end

    def calculate_invalid_moves
      Rails.logger.info "-- Rulebook.calculate_invalid_moves -- just entered"
      killing_moves = get_killing_moves

      # ugly hack to add positions from new_killing_mvoes into killing_moves, if any
      # this should be moved into get_killing_moves?
      if @new_killing_moves
        Rails.logger.info "-- Rulebook.calculate_invalid_moves -- @new_killing_moves: #{@new_killing_moves.inspect}"
        TILE_VALUES.values.each do |color|
          @new_killing_moves[color].each { |pos| killing_moves[color][pos] = true }
        end
      end

      _invalid_moves = { @active_player_color => Set.new, @enemy_color => Set.new }

      single_liberty_groups.each do |single_lib_group_id, libs|
        color = @colors[single_lib_group_id]
        pos_of_only_liberty = libs.to_a.pop
        move_would_result_in_zero_libs = true

        neighbors(pos_of_only_liberty).each do |neighbor_pos|
          neighbor_id = @group_ids[neighbor_pos]

          # if neighbor_pos is part of different group, then need to keep checking
          if neighbor_id && neighbor_id != single_lib_group_id
            same_color = (@colors[neighbor_id] == color)
            more_than_one_lib = (@liberties[neighbor_id].size > 1)

            # valid if filling in this single lib connects to friendly group with two or more libs
            if same_color && more_than_one_lib
              move_would_result_in_zero_libs = false
            end
          # also valid if filling in the single lib places group next to another lib (EMPTY tile)
          elsif @board[neighbor_pos] == EMPTY
            move_would_result_in_zero_libs = false
          end
        end

        # if would result in zero libs, and does not kill an enemy group --> invalid move
        if move_would_result_in_zero_libs && (not killing_moves[color].key?(pos_of_only_liberty))
          _invalid_moves[color].add(pos_of_only_liberty)
        end

        # or, if it is a ko posotion (despite the fact that ko positions are all killing moves)
        if @_ko_position && @_ko_position[opposing_color(color)] == pos_of_only_liberty
          _invalid_moves[opposing_color(color)].add(pos_of_only_liberty)
        end
      end

      all_liberties.each do |empty_pos|
        neighbor_tiles = neighbor_tile_types(empty_pos)

        enemy_neighbor_count = neighbor_tiles.count { |tile| tile == @enemy_color }
        surrounded_by_enemies = (enemy_neighbor_count == neighbor_tiles.size)

        friendly_neighbor_count = neighbor_tiles.count { |tile| tile == @active_player_color }
        surrounded_by_friends = (friendly_neighbor_count == neighbor_tiles.size)

        if surrounded_by_enemies && (not killing_moves[@active_player_color].key?(empty_pos))
          _invalid_moves[@active_player_color].add(empty_pos)
        elsif surrounded_by_friends && (not killing_moves[@enemy_color].key?(empty_pos))
          _invalid_moves[@enemy_color].add(empty_pos)
        end
      end

      Rails.logger.info "-- Rulebook.calculate_invalid_moves -- done!! results: #{_invalid_moves.inspect}"

      # return a hash with :white/:black as keys, instead of board DB table color vals (true/false)
      { TILE_VALUES_REVERSE[@active_player_color] => _invalid_moves[@active_player_color],
        TILE_VALUES_REVERSE[@enemy_color] => _invalid_moves[@enemy_color] }
    end

    def update_neighbors(pos, color)
      potential_new_libs = neighbors(pos).select { |neighbor_pos| @board[neighbor_pos] == EMPTY }

      log_msg = "pos: #{pos.inspect}, color: #{color.inspect}, potential_new_libs: #{potential_new_libs.inspect}"
      Rails.logger.info "-- Rulebook.update_neighbors -- #{log_msg}"

      # update neighboring groups
      neighbors(pos).each do |neighbor_pos|
        neighbor_group = @group_ids[neighbor_pos]
        @liberties[neighbor_group].delete(pos) if neighbor_group

        # new stone is connected to friendly group (same color)
        if @colors[neighbor_group] == color

          # add new stone to the group it is now connected to
          if @group_ids[pos] == nil
            @group_ids[pos] = neighbor_group
            @members[neighbor_group].add(pos)
            @liberties[neighbor_group].delete(pos)
            @liberties[neighbor_group].merge(potential_new_libs)

          # unless we already added it to a group (then merge those two)
          elsif @group_ids[pos] != neighbor_group
            merge_groups(@group_ids[pos], neighbor_group)
          end
        end
      end

      # check for new killing moves
      neighbors(pos).each do |neighbor_pos|
        neighbor_group = @group_ids[neighbor_pos]

        # if neighbor is enemy and now only has 1 lib, then that lib is a killing move for 'color'
        if (@colors[neighbor_group] == opposing_color(color)) && (@liberties[neighbor_group].size == 1)
          @new_killing_moves[color].add @liberties[neighbor_group].to_a.pop
          Rails.logger.info "--- adding to new_killing_moves, v1 --- neighbor: #{@members[neighbor_group].inspect}"
        end

        if @colors[neighbor_group] == color
          if @liberties[@group_ids[pos]].size == 1
            @new_killing_moves[opposing_color(color)].add @liberties[@group_ids[pos]].to_a.pop
            Rails.logger.info "--- adding to new_killing_moves, v2 --- pos group: #{@members[@group_ids[pos]].inspect}"
          end
        end
      end

      if @group_ids[pos] == nil
        add_new_group(pos)
        @liberties[@group_ids[pos]].merge(potential_new_libs)
      end
    end

    def capture_group(group)
      @members[group].each do |captured_pos|
        @group_ids.delete(captured_pos)
      end
      @liberties.delete(group)
      @colors.delete(group)

      @members[group].each do |captured_pos|
        add_as_liberty_to_neighbors(captured_pos)
        @board[captured_pos] = EMPTY
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
      # hash values are sets of group ids, as some moves can kill multiple groups
      killing_moves = {
        @active_player_color => Hash.new { |hash, key| hash[key] = Set.new },
        @enemy_color => Hash.new { |hash, key| hash[key] = Set.new }
      }

      # tiles that are the only lib for a group are killing moves for the opponent (of that group)
      single_liberty_groups.each do |group_id, libs|
        killing_move_pos = libs.to_a.pop

        if @colors[group_id] == @enemy_color
          killing_moves[@active_player_color][killing_move_pos].add(group_id)
        else
          killing_moves[@enemy_color][killing_move_pos].add(group_id)
        end
      end

      Rails.logger.info "-- Rulebook.get_killing_moves (done): killing_moves= #{killing_moves.inspect}"
      killing_moves
    end

    def check_for_ko(killing_move, captured_groups)
      captured_group = captured_groups.to_a.pop

      if @members.key?(captured_group) && (@members[captured_group].size == 1)
        captured_stone = @members[captured_group].to_a.pop
        Rails.logger.info "-- Rulebook.check_for_ko: captured_stone = #{captured_stone.inspect}"

        killing_stone_is_immediately_recapturable = true

        neighbors(killing_move).each do |neighbor_pos|
          neighbor_group = @group_ids[neighbor_pos]

          is_captured_stone = (captured_stone == neighbor_pos)
          is_enemy_stone = (neighbor_group && (@colors[neighbor_group] == @enemy_color))

          log_msg = "nieghbor_pos= #{neighbor_pos.inspect}, neighbor_group= #{neighbor_group.inspect}"
          log_msg << ", is_captured_stone= #{is_captured_stone.inspect}, is_enemy_stone= #{is_enemy_stone.inspect}"
          Rails.logger.info "-- Rulebook.check_for_ko: #{log_msg}"

          if not (is_captured_stone || is_enemy_stone)
            killing_stone_is_immediately_recapturable = false
          end
        end

        if killing_stone_is_immediately_recapturable
          @_ko_position = { @enemy_color => captured_stone }
          Rails.logger.info "-- Rulebook.check_for_ko -- ko was found! @_ko_position: #{@_ko_position.inspect}"
        end
      end
    end

    def single_liberty_groups
      @liberties.select { |group_id, libs| (libs.size == 1) }
    end

    def all_liberties
      all_libs = Set.new
      @liberties.keys.each { |group_id| all_libs.merge(@liberties[group_id]) }
      all_libs
    end

    def build_groups
      @board.each_with_index do |tile_type, pos|
        up, left = up_and_left_neighbors(pos)
        up_group, left_group = get_group_ids(up, left)

        if tile_type == EMPTY
          @liberties[left_group].add(pos) if left_group
          @liberties[up_group].add(pos) if up_group

        else
          # if same color as left stone, add to that group
          if left && (tile_type == @colors[left_group])
            @members[left_group].add(pos)
            @group_ids[pos] = left_group
          end

          # if same color as up stone, add to that group
          if up && (tile_type == @colors[up_group])

            # check if already added to left group, and if up group is different, then combine the two
            if left_group && @members[left_group].include?(pos) && left_group != up_group
              merge_groups(left_group, up_group)
              up_group = left_group

            # else just add to up group as usual
            else
              @members[up_group].add(pos)
              @group_ids[pos] = up_group
            end
          end

          if not @group_ids[pos]
            add_new_group(pos)
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

    def add_new_group(pos)
      @group_count += 1
      new_group_id = @group_count

      @group_ids[pos] = new_group_id
      @members[new_group_id].add(pos)
      @colors[new_group_id] = @board[pos]
    end

    # combine group 2 with group 1, and remove group 2
    def merge_groups(group_1, group_2)
      @members[group_2].each do |pos|
        @group_ids[pos] = group_1
      end
      @members[group_1].merge(@members[group_2])
      @liberties[group_1].merge(@liberties[group_2])

      # remove prior references to group 2
      @members.delete(group_2)
      @liberties.delete(group_2)
      @colors.delete(group_2)
    end

    # a neighbor is a directly adjacent tile (horizontal and vertical, not diagonal)
    # middle tiles have 4, edges have 3, corners only have 2

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

    def opposing_color(color)
      (TILE_VALUES.values.select { |val| val != color }).pop
    end

  end

end
