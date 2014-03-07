module Scoring

  EMPTY = GoApp::EMPTY_TILE
  BLACK = GoApp::BLACK_STONE
  WHITE = GoApp::WHITE_STONE
  STONES = [BLACK, WHITE]

  DB_VAL_TO_COLOR = { BLACK => :black, WHITE => :white }
  COLOR_TO_DB_VAL = { :black => BLACK, :white => WHITE }
  OPPOSING_COLOR = { BLACK => WHITE, WHITE => BLACK }
  EXPIRE_TIME = 10 * 60

  class Scorebot

    def initialize(params)
      @nosql_key = params[:nosql_key]
      @overwrite = params.fetch(:overwrite, false)
      @test_mode = params.fetch(:test_mode, false)

      @black_captures = params[:black_captures]
      @white_captures = params[:white_captures]
      @komi = params.fetch(:komi, 0)
      @initial_analysis = true

      fetch_or_prep_scoring_data(params)
    end

    def prep_scoring_data(params)
      @board = BoardAnalyzer.new(size: params[:size], board: params[:board])
      compute_initial_scores
    end

    def changed_tiles
      @board.changed_tiles(initial_analysis?) || []
    end

    def point_count(color)
      if color == :black
        black_point_count
      elsif color == :white
        white_point_count
      end
    end

    def black_point_count
      @scores[BLACK]
    end

    def white_point_count
      @scores[WHITE]
    end

    def has_dead_stone?(tile_pos)
      @board.has_dead_stone?(tile_pos)
    end

    def dead_stones
      @board.dead_stones.dup
    end

    def territory_counts(color)
      @territory_counts[COLOR_TO_DB_VAL[color]]
    end

    def territory_status(tile_pos)
      @board.territory_status(tile_pos)
    end

    def territory_tiles
      @board.territory_tiles.dup
    end

    def dead_stone_count(color)
      @board.dead_stone_counts[COLOR_TO_DB_VAL[color]]
    end

    def mark_as_dead(stone_pos)
      @initial_analysis = false
      mark(stone_pos, :dead)
    end

    def mark_as_not_dead(stone_pos)
      @initial_analysis = false
      mark(stone_pos, :not_dead)
    end

    # OPTIMIZATION IDEA: have two hunks of data in redis
    # first only has the bare minimum data needed to determine if a scoring update action is valid
    # if the action is valid, only then load the board objects & scoring data and process the action
    def mark(stone_pos, new_status)
      Rails.logger.info "==== starting.. -- marking #{stone_pos} with status: #{new_status.inspect}"
      prep_for_new_action

      action_was_valid =
        if new_status == :dead
          @board.mark_as_dead(stone_pos)
        elsif new_status == :not_dead
          @board.mark_as_not_dead(stone_pos)
        end

      if action_was_valid
        update_scores
        dump_current_scoring_state_into_data_store
      end

      Rails.logger.info "==== done.. -- marking #{stone_pos} with status: #{new_status.inspect}"
      action_was_valid
    end

    def prep_for_new_action
      @board.reset_cached_instance_vars
    end

    # there is probably a way to avoid redoing the entire score calculation
    def update_scores
      @scores = Hash.new(0)

      @board.meta_chains.each do |meta_chain|
        # do we need the recalculate flag?
        @scores[meta_chain.color] += meta_chain.territory_counts(recalculate=true)
      end
      @board.chains.each do |chain|
        # only add territory from chains that are not part of a metachain
        @scores[chain.color] += chain.territory_counts unless @board.has_container?(chain)
      end

      add_captures_and_komi_to_scores
    end

    def compute_initial_scores
      @scores = @board.initial_territory_counts
      add_captures_and_komi_to_scores
    end

    def add_captures_and_komi_to_scores
      # before we add the non territory items to @scores, copy territory data into @territory_counts instance var
      @territory_counts = @scores.dup

      @scores[BLACK] += @board.dead_stone_counts[WHITE] + @black_captures
      @scores[WHITE] += @board.dead_stone_counts[BLACK] + @white_captures
      @scores[WHITE] += @komi if @komi
    end

    def initial_analysis?
      @initial_analysis
    end

    def fetch_or_prep_scoring_data(params)
      Rails.logger.info "==== Scorebot.fetch_or_prep_scoring_data -- @nosql_key: #{@nosql_key}"
      existing_data_found = $redis.exists(@nosql_key) if $redis
      Rails.logger.info "==== Scorebot.fetch_or_prep_scoring_data -- $redis.exists(..): #{existing_data_found.inspect}"

      if existing_data_found && !@overwrite && !@test_mode
        marshal_dump = $redis.get(@nosql_key)
        $redis.expire(@nosql_key, EXPIRE_TIME)
        load_scoring_data(marshal_dump)
      else
        prep_scoring_data(params)
        dump_current_scoring_state_into_data_store unless @test_mode
      end
    end

    def dump_current_scoring_state_into_data_store
      log_msg = "performing $redis.set with key: #{@nosql_key.inspect}"
      Rails.logger.info "==== Scorebot.fetch_or_prep_scoring_data -- #{log_msg}"

      marshal_dump = Marshal.dump(data_to_dump)
      Rails.logger.info "==== Scorebot.fetch_or_prep_scoring_data -- marshal_dump.length: #{marshal_dump.length}"
      $redis.set(@nosql_key, marshal_dump)
      $redis.expire(@nosql_key, EXPIRE_TIME)
    end

    def load_scoring_data(marshal_dump)
      loaded_data = Marshal.load(marshal_dump)
      Rails.logger.info "=== Scorebot.load_scoring_data -- (@board != nil): #{(@board != nil).inspect}"

      loaded_data.each do |instance_var_symbol, obj|
        instance_variable_set(instance_var_symbol, obj)
      end

      Rails.logger.info "=== Scorebot.load_scoring_data -- data loaded successfully!"
      Rails.logger.info "=== group count: #{@board.stone_groups.size}, chain count: #{@board.chains.size}"
    end

    def data_to_dump
      { :@board => @board, :@scores => @scores, :@territory_counts => @territory_counts }
    end
  end


  class BoardAnalyzer

    def initialize(params)
      @board = params[:board]
      @size = params[:size]
      @manager = ContainerManager.new(board_analyzer: self)

      analyze
    end

    def stone_groups
      @manager.stone_groups
    end

    def tile_zones
      @manager.tile_zones
    end

    def chains
      @manager.chains
    end

    def meta_chains
      @manager.meta_chains
    end

    def reset_cached_instance_vars
      @changed_tiles = nil
      @changed_tile_sets = Set.new
      @territory_tiles = nil
    end

    def initial_territory_counts
      counts = Hash.new(0)
      chains.each { |chain| counts[chain.color] += chain.surrounded_tile_count if chain.alive? }
      counts
    end

    def territory_status(tile_pos)
      (:black if territory_tiles[BLACK].include?(tile_pos)) || (:white if territory_tiles[WHITE].include?(tile_pos))
    end

    def territory_tiles
      @territory_tiles ||= identify_territory_tiles
    end

    def identify_territory_tiles
      tiles = { BLACK => Set.new, WHITE => Set.new }

      meta_chains.each do |meta_chain|
        meta_chain.resulting_territory_tile_sets(include_alive_chains=true).each do |tile_set|
          tiles[meta_chain.color] += tile_set
        end
      end
      chains.each do |chain|
        tiles[chain.color].merge(chain.surrounded_tiles) if chain.alive? && doesnt_have_container?(chain)
      end

      tiles
    end

    def dead_stones
      @dead_stones ||= Set.new
    end

    def dead_stone_counts(color=nil)
      @dead_stone_counts ||= Hash.new(0)
    end

    def remove_chain_from_dead_stone_list(chain)
      @dead_stones.subtract(chain.stone_tiles)
      dead_stone_counts[chain.color] -= chain.stone_tiles.size
    end

    def add_chain_to_dead_stone_list(chain)
      @dead_stones.merge(chain.stone_tiles)
      dead_stone_counts[chain.color] += chain.stone_tiles.size
    end

    def changed_tiles(initial_analysis=false)
      @changed_tiles ||=
        if initial_analysis
          territory_tiles.values.inject(Set.new) { |cache, tile_sets| cache += tile_sets }
        else
          @changed_tile_sets.flatten
        end
    end

    def analyze
      identify_stone_groups_and_tile_zones
      combine_stone_groups_into_chains
    end

    def identify_stone_groups_and_tile_zones
      tiles_positions.each do |pos|
        update_board_containers_with_new_tile(pos)
        update_container_neighbor_data(pos)
      end
    end

    def update_board_containers_with_new_tile(new_pos)
      neighboring_tiles_that_have_been_processed(new_pos).each do |neighbor_pos|
        if same_tile_types(new_pos, neighbor_pos)
          if has_container?(new_pos)
            merge_containers(find_container(new_pos), find_container(neighbor_pos))
          else
            find_container(neighbor_pos).add_member(new_pos)
          end
        end
      end

      # if neighbors are not of same type, then it wasn't added to an existing container, so create new one
      create_container(new_pos, tile_state: tile_state(new_pos)) unless has_container?(new_pos)
    end

    def update_container_neighbor_data(pos)
      container = find_container(pos)

      neighboring_tiles_that_have_been_processed(pos).each do |neighbor_pos|
        neighboring_container = find_container(neighbor_pos)

        unless same_tile_types(pos, neighbor_pos)
          container.add_neighbor(neighboring_container)
          neighboring_container.add_neighbor(container)
        end

        # add liberties to stone groups
        if has_stone?(pos) && is_empty?(neighbor_pos)
          container.add_liberty(neighbor_pos)
        elsif is_empty?(pos) && has_stone?(neighbor_pos)
          neighboring_container.add_liberty(pos)
        end
      end
    end

    def combine_stone_groups_into_chains
      tile_zones.each do |zone|
        determine_and_set_eye_status(zone)
        chains_around_this_zone = {} # by definition, at most one of each color

        zone.neighbors.each do |stone_group|
          current_chain = chains_around_this_zone[stone_group.color]

          if has_container?(stone_group)
            merge_containers(find_container(stone_group), current_chain) if current_chain
            chains_around_this_zone[stone_group.color] = find_container(stone_group)

          else
            if current_chain
              current_chain.add_member(stone_group)
            else
              chains_around_this_zone[stone_group.color] = create_container(stone_group)
            end
          end

          stone_group.neighboring_enemy_groups.each do |neighbor_group|
            create_container(neighbor_group) unless has_container?(neighbor_group)
            neighboring_enemy_chain = find_container(neighbor_group)

            chains_around_this_zone[stone_group.color].add_enemy_neighbor(neighboring_enemy_chain)
            neighboring_enemy_chain.add_enemy_neighbor(chains_around_this_zone[stone_group.color])
          end
        end

        chains_around_this_zone.each do |color, chain|
          chain.add_neighboring_zone(zone)
          zone.set_chain_neighbor(chain)
        end
      end
    end

    def mark_as_dead(tile_pos)
      if has_dead_stone?(tile_pos) || is_empty?(tile_pos)
        false
      else
        new_dead_chain = find_container(find_container(tile_pos))

        if has_container?(new_dead_chain)
          meta_chain = find_container(new_dead_chain)
          meta_chain.remove_alive_member_chain(new_dead_chain)

          # all nearby enemy chains need to be alive (can't have dead chains of different colors next to each other)
          new_dead_chain.all_reachable_enemy_chains.each do |formerly_dead_chain|

            if meta_chain.has_dead_chain?(formerly_dead_chain)
              meta_chain.remove_dead_member_chain(formerly_dead_chain)
              record_changed_tiles(formerly_dead_chain.all_tile_sets)
              remove_chain_from_dead_stone_list(formerly_dead_chain)

              if meta_chain.no_longer_needed?
                meta_chain.alive_chains.each do |chain|
                  # the surrounded tiles are former territory points if the chain isnt alive by itself
                  record_changed_tiles(chain.surrounded_tiles) if chain.not_alive?
                end
                meta_chain.delete_references
              end
            end
          end
        end

        new_dead_chain.all_reachable_enemy_chains.each do |enemy_chain|
          if has_container?(enemy_chain)
            find_container(enemy_chain).add_member(new_dead_chain)
            break
          end
        end

        if doesnt_have_container?(new_dead_chain)
          create_container(new_dead_chain)
          record_changed_tiles(find_container(new_dead_chain).resulting_territory_tile_sets)
        end

        record_changed_tiles(new_dead_chain.all_tile_sets)
        add_chain_to_dead_stone_list(new_dead_chain)

        true
      end
    end

    def mark_as_not_dead(tile_pos)
      if doesnt_have_dead_stone?(tile_pos) || is_empty?(tile_pos)
        false
      else
        formerly_dead_chain = find_container(find_container(tile_pos))
        meta_chain = find_container(formerly_dead_chain)

        meta_chain.remove_dead_member_chain(formerly_dead_chain)
        record_changed_tiles(formerly_dead_chain.all_tile_sets)
        remove_chain_from_dead_stone_list(formerly_dead_chain)
        meta_chain.delete_references if meta_chain.no_longer_needed?

        formerly_dead_chain.all_reachable_enemy_chains.each do |enemy_chain|
          if enemy_chain.not_alive? && doesnt_have_container?(enemy_chain)
            record_changed_tiles(enemy_chain.surrounded_tiles)
          end
        end

        true
      end
    end

    def find_container(member_key)
      @manager.find_owner(member_key)
    end

    def has_container?(member_key)
      @manager.has_owner?(member_key)
    end
    def doesnt_have_container?(member_key); !@manager.has_owner?(member_key) end

    def find_containers(*member_keys)
      member_keys.map { |member_key| find_container(member_key) }
    end

    def create_container(member_key, params={})
      @manager.create_container(member_key, params)
    end

    def merge_containers(container1, container2)
      @manager.merge_containers(container1, container2)
    end

    def tiles_positions
      (0...@board.size)
    end

    def same_tile_types(pos1, pos2)
      tile_state(pos1) == tile_state(pos2)
    end

    def is_empty?(pos)
      tile_state(pos) == EMPTY
    end

    def has_stone?(pos)
      STONES.include?(tile_state(pos))
    end

    def has_dead_stone?(pos)
      dead_stones.include?(pos)
    end
    def doesnt_have_dead_stone?(pos); !has_dead_stone?(pos) end

    def tile_state(pos)
      @board[pos]
    end

    def record_changed_tiles(tile_sets)
      @changed_tile_sets += tile_sets
    end

    # as we scan board and construct data structures for score analysis, only use neighbors above & to the left
    # of each tile. due to iteration pattern (from top left to bottom right), these have already been processed
    def neighboring_tiles_that_have_been_processed(pos)
      _neighbors = []

      if pos % @size != 0
        _neighbors << pos - 1
      end
      if pos - @size >= 0
        _neighbors << pos - @size
      end

      _neighbors
    end

    def neighbors(pos, options={})
      all = options[:all] || (true if options.size == 0)
      _neighbors = []

      if (options[:left] || all)  && pos % @size != 0
        _neighbors << pos - 1
      end
      if (options[:right] || all) && (pos + 1) % @size != 0
        _neighbors << pos + 1
      end
      if (options[:above] || all) && pos - @size >= 0
        _neighbors << pos - @size
      end
      if (options[:below] || all) && pos + @size < @size**2
        _neighbors << pos + @size
      end

      _neighbors
    end

    def determine_and_set_eye_status(tile_zone)
      is_eye = false

      if tile_zone.surrounded?
        if tile_zone.size > 2
          is_eye = true

        else
          diagonals = diagonally_neighboring_tiles(tile_zone.tiles)
          empty_diagonal_count = diagonals.select { |tile| is_empty?(tile) }.size

          # this is quite close to saying 'can we connect the neighboring groups with the empty diagonals?'
          if (tile_zone.neighbor_count - empty_diagonal_count) <= tile_zone.size
            is_eye = true

          elsif tile_zone.size == 2
            is_eye = is_one_of_the_tiles_an_eye_if_we_pretend_other_tile_is_a_friendly_stone?(tile_zone)
          end
        end
      end

      tile_zone.set_eye_status(is_eye)
    end

    def is_one_of_the_tiles_an_eye_if_we_pretend_other_tile_is_a_friendly_stone?(tile_zone)
      answer = false
      tile_zone.tiles.each do |tile|
        other_tile = tile_zone.tiles.dup.delete(tile).to_a.pop

        neighbors_not_connected_by_tile = tile_zone.neighbors.reject { |group| group.has_liberty?(tile) }

        pseudo_neighbor_count = 1 + neighbors_not_connected_by_tile.size
        pseudo_diagonals = diagonally_neighboring_tiles(other_tile)
        pseudo_empty_diagonal_count = pseudo_diagonals.select { |tile| is_empty?(tile) }.size

        answer = true if (pseudo_neighbor_count - pseudo_empty_diagonal_count) <= 1
      end
      answer
    end

    def diagonally_neighboring_tiles(tiles)
      tiles = [tiles] if tiles.is_a?(Integer)

      if tiles.size == 1
        diagonals_for_tile(tiles.to_a[0], all: true)

      elsif tiles.size == 2
        closer_to_top_left, closer_to_bot_right = tiles.sort

        # vertically aligned
        if closer_to_bot_right - closer_to_top_left == @size
          diagonals_for_tile(closer_to_top_left,  top_left: true, top_right: true).concat(
          diagonals_for_tile(closer_to_bot_right, bot_left: true, bot_right: true))

        # horizontally aligned
        else
          diagonals_for_tile(closer_to_top_left,  top_left: true,   bot_left: true).concat(
          diagonals_for_tile(closer_to_bot_right, top_right: true,  bot_right: true))
        end
      end
    end

    def diagonals_for_tile(pos, corners = {})
      not_on_left_edge  = (pos % @size != 0)
      not_on_right_edge = ((pos + 1) % @size != 0)
      not_on_top_edge   = (pos - @size >= 0)
      not_on_bot_edge   = (pos + @size < @size**2)

      diagonals = []

      if (corners[:top_left] || corners[:all])  && not_on_top_edge && not_on_left_edge
        diagonals << pos - (@size + 1)
      end
      if (corners[:top_right] || corners[:all]) && not_on_top_edge && not_on_right_edge
        diagonals << pos - (@size - 1)
      end
      if (corners[:bot_left] || corners[:all])  && not_on_bot_edge && not_on_left_edge
        diagonals << pos + (@size - 1)
      end
      if (corners[:bot_right] || corners[:all]) && not_on_bot_edge && not_on_right_edge
        diagonals << pos + (@size + 1)
      end

      diagonals
    end
  end


  class ContainerManager

    def initialize(params)
      @board_analyzer = params[:board_analyzer]
      @instance_counts = Hash.new(0)

      @instances      = {}
      @owners         = {}
      @assimilations  = {}
    end

    # @instances[container_class_key] => { container_instance_id => container_instance, ... }
    def instances(class_key)
      @instances[class_key] = {} unless @instances.key?(class_key)
      @instances[class_key]
    end

    # @owners[container_class_key] => { member_instance => container_instance_id, ... }
    def owners(class_key)
      @owners[class_key] = {} unless @owners.key?(class_key)
      @owners[class_key]
    end

    # @assimilations[container_class_key] => { container_instance_id => container_instance_id, ... }
    # whenever two groups merge, one assimilates the other
    # we redirect the old id to the assmimilator's id, so member lookups will return correct container instance
    def assimilations(class_key)
      @assimilations[class_key] = {} unless @assimilations.key?(class_key)
      @assimilations[class_key]
    end

    def stone_groups
      instances(StoneGroup.class_key).values
    end

    def tile_zones
      instances(TileZone.class_key).values
    end

    def chains
      instances(Chain.class_key).values
    end

    def meta_chains
      instances(MetaChain.class_key).values
    end

    def create_container(initial_member_key, params={})
      params[:manager] = self
      container_class(initial_member_key).new(initial_member_key, params)
    end

    def add_container(new_container_instance)
      class_key = new_container_instance.class_key
      instance_id = (@instance_counts[class_key] += 1)
      instances(class_key)[instance_id] = new_container_instance
      instance_id
    end

    def remove_container(doomed_instance)
      instances(doomed_instance.class_key).delete(doomed_instance.instance_id)
    end

    def remove_container_and_member_lookups(doomed_instance)
      class_key = doomed_instance.class_key

      doomed_instance.members.each do |member|
        clear_assimilation_mappings(owners(class_key)[member], class_key)
        owners(class_key).delete(member)
      end

      instances(class_key).delete(doomed_instance.instance_id)
    end

    def add_member_lookup(member_key, container_instance)
      owners(container_instance.class_key)[member_key] = container_instance.instance_id
    end

    def delete_member_lookup(member_key, container_instance)
      owners(container_instance.class_key).delete(member_key)
    end

    def has_owner?(member_key)
      class_key = container_class(member_key).class_key
      owners(class_key).key?(member_key)
    end

    def find_owner(member_key)
      class_key = container_class(member_key).class_key
      owner_id = owners(class_key)[member_key]
      fetch_instance_or_assimilator_instance(owner_id, class_key)
    end

    def fetch_instance_or_assimilator_instance(instance_id, class_key)
      most_current_id = instance_id
      _assimilations = assimilations(class_key)

      if _assimilations.key?(most_current_id)
        # there might have been several assimilations (merges), loop through to get the current container
        most_current_id = _assimilations[most_current_id] while _assimilations.key?(most_current_id)

        # update hash so original instance_id points directly to the instance_id of the most recent assimilator
        _assimilations[instance_id] = most_current_id
      end

      instances(class_key)[most_current_id]
    end

    def clear_assimilation_mappings(instance_id, class_key)
      _assimilations = assimilations(class_key)
      instance_id = _assimilations.delete(instance_id) while _assimilations.key?(instance_id)
    end

    def merge_containers(container1, container2)
      smaller, larger = order_by_size(container1, container2)
      class_key = smaller.class_key

      # dont merge if they are the same
      unless smaller.instance_id == larger.instance_id
        assimilations(class_key)[smaller.instance_id] = larger.instance_id

        larger.add_assimilated_members(smaller.members)
        update_neighbors_during_merge(larger, smaller)

        larger.assimilate(smaller)
        remove_container(smaller)
      end
    end

    def order_by_size(*containers)
      containers.sort { |a,b| a.size <=> b.size }
    end

    def update_neighbors_during_merge(assimilator, assimilated)
      assimilated.all_neighbor_types.each do |type, set_of_neighbors|
        set_of_neighbors.each { |neighbor| neighbor.replace_neighbor(assimilated, assimilator) }
        assimilator.neighbors_of_type(type).merge(set_of_neighbors)
      end
    end

    def container_class(member_key)
      if member_key.is_a?(Integer)
        (TileZone if @board_analyzer.is_empty?(member_key)) || StoneGroup
      elsif member_key.instance_of?(StoneGroup)
        Chain
      elsif member_key.instance_of?(Chain)
        MetaChain
      end
    end
  end


  class Container
    attr_reader :instance_id, :members

    def self.class_key
      self.to_s.to_sym
    end

    def class_key
      self.class.class_key
    end

    def initialize(initial_member_key, params={})
      @manager = params[:manager]
      @instance_id = @manager.add_container(self)
      add_member_lookup(initial_member_key)
    end

    # sub-classes should create a '@members' Set
    def add_member(new_member)
      @members.add(new_member)
      add_member_lookup(new_member)
    end

    # we dont add member lookups here, because we rely on the @manager assimilations redirecter
    def add_assimilated_members(new_members)
      @members.merge(new_members)
    end

    def add_member_lookup(member_key)
      @manager.add_member_lookup(member_key, self)
    end

    def add_member_lookups(member_keys)
      member_keys.each { |member_key| @manager.add_member_lookup(member_key, self) }
    end

    def delete_member_lookup(member_key)
      @manager.delete_member_lookup(member_key, self)
    end

    def size
      @members.size
    end

    def delete_references
      @manager.remove_container_and_member_lookups(self)
    end

    # sub-classes need to have a '@neighbors' hash. keys: container type, valus: set of container instances
    def all_neighbor_types
      @neighbors
    end

    def neighbors_of_type(type)
      @neighbors[type]
    end

    # place holder method -- if sub-class has extra work to do during a merge, should overwrite this
    def assimilate(other_container)
    end

    def replace_neighbor(old_neighbor, new_neighbor)
      # only add new_neighbor if old_neighbor was actually a neighbor (if remove_neighbor -> true)
      add_neighbor(new_neighbor) if remove_neighbor(old_neighbor)
    end

    # base classes need to implement the 'neighbor_type' method, which returns correct key for @neighbors hash
    def add_neighbor(neighboring_container)
      @neighbors[neighbor_type(neighboring_container)].add(neighboring_container)
    end

    def remove_neighbor(neighboring_container)
      @neighbors[neighbor_type(neighboring_container)].delete?(neighboring_container)
    end

    def inspect(params = {})
      skip = params.fetch(:skip, [:@neighbors]).concat([:@manager])
      inspected_vars = instance_variables.map do |var|
        "#{var}=#{instance_variable_get(var).inspect}" unless skip.include?(var)
      end
      "#<#{self.class}:0x%x %s>" % [object_id * 2, inspected_vars.compact.join(", ")]
    end
  end


  class TileZone < Container
    def initialize(initial_tile_pos, params={})
      @members = Set.new([initial_tile_pos])
      @neighbors = { black: Set.new, white: Set.new }
      @neighboring_chains = {}

      super
    end

    def tiles
      @members
    end

    def surrounded?
      (@neighbors[:black].size == 0) || (@neighbors[:white].size == 0)
    end

    def surrounding_color
      if @neighbors[:white].size == 0
        :black
      elsif @neighbors[:black].size == 0
        :white
      end
    end

    def neighboring_groups(color)
      @neighbors[color]
    end

    def neighbors
      @neighbors[:black].union(@neighbors[:white])
    end

    def neighbor_count
      @neighbors[:black].size + @neighbors[:white].size
    end

    def set_chain_neighbor(chain)
      @neighboring_chains[chain.color] = chain
    end

    def neighboring_chain(color)
      @neighboring_chains[color]
    end

    def neighbor_type(stone_group)
      if stone_group.color == BLACK
        :black
      elsif stone_group.color == WHITE
        :white
      end
    end

    def is_eye?
      @is_eye
    end

    def set_eye_status(is_eye)
      @is_eye = is_eye
    end
  end

  class StoneGroup < Container
    attr_reader :color, :liberties

    def initialize(initial_stone_pos, params={})
      @members = Set.new([initial_stone_pos])
      @liberties = Set.new
      @color = params[:tile_state]
      @neighbors = { enemy_groups: Set.new, tile_zones: Set.new }

      super
    end

    def stones
      @members
    end

    def add_liberty(tile_pos)
      liberties.add(tile_pos)
    end

    def has_liberty?(tile_pos)
      liberties.include?(tile_pos)
    end

    def assimilate(other_group)
      @liberties.merge(other_group.liberties)
    end

    def neighboring_enemy_groups
      @neighbors[:enemy_groups]
    end

    def neighboring_tile_zones
      @neighbors[:tile_zones]
    end

    def neighbor_type(stone_group_or_tile_zone)
      (:tile_zones if stone_group_or_tile_zone.is_a?(TileZone)) || :enemy_groups
    end
  end


  class Chain < Container
    attr_reader :color, :eyes, :surrounded_tile_count

    def initialize(initial_stone_group, params={})
      @members = Set.new([initial_stone_group])
      @color = initial_stone_group.color
      @surrounded_tile_count = 0
      @eyes = {}
      @neighbors = { enemy_chains: Set.new, surrounded_zones: Set.new, neutral_zones: Set.new }

      super
    end

    def groups
      @members
    end

    def alive?
      @eyes.size >= 2 || (@has_an_eye_size_3_or_greater == true)
    end
    def not_alive?; !alive? end

    def all_tile_sets
      Set.new([stone_tiles, surrounded_tiles, neutral_tiles])
    end

    def surrounded_tiles
      surrounded_zones.inject(Set.new) { |tile_set, zone| tile_set.merge(zone.tiles) }
    end

    def stone_tiles
      groups.inject(Set.new) { |stone_set, group| stone_set.merge(group.stones) }
    end

    def neutral_tiles
      neutral_zones.inject(Set.new) { |cache, zone| cache.merge(zone.tiles) }
    end

    def assimilate(other_chain)
      @eyes.update(other_chain.eyes)
      @surrounded_tile_count += other_chain.surrounded_tile_count

      [:surrounded_zones, :neutral_zones].each do |zone_type|
        other_chain.neighbors_of_type(zone_type).each { |zone| zone.set_chain_neighbor(self) }
      end
    end

    def add_neighboring_zone(zone)
      if zone.surrounded?
        @neighbors[:surrounded_zones].add(zone)
        @surrounded_tile_count += zone.size
      else
        @neighbors[:neutral_zones].add(zone)
      end

      if zone.is_eye?
        @eyes[zone] = true
        @has_an_eye_size_3_or_greater = true if zone.size >= 3
      end
    end

    def add_enemy_neighbor(enemy_chain)
      @neighbors[:enemy_chains].add(enemy_chain)
    end

    def all_reachable_enemy_chains
      chains = neighboring_enemy_chains.dup
      neutral_zones.each { |zone| chains.add(zone.neighboring_chain(OPPOSING_COLOR[@color])) }
      chains
    end

    def neighboring_enemy_chains
      @neighbors[:enemy_chains]
    end

    def surrounded_zones
      @neighbors[:surrounded_zones]
    end

    def neutral_zones
      @neighbors[:neutral_zones]
    end

    def territory_counts
      (@surrounded_tile_count if alive?) || 0
    end

    def has_eye?(zone)
      @eyes.key?(zone)
    end

    def neighbor_type(neighboring_container)
      if neighboring_container.is_a?(TileZone)
        (:surrounded_zones if neighboring_container.surrounded?) || :neutral_zones
      elsif neighboring_container.color != @color
        :enemy_chains
      end
    end
  end

  class MetaChain < Container
    attr_reader :color, :dead_chains, :alive_chains

    def initialize(initial_dead_chain, params={})
      @color = OPPOSING_COLOR[initial_dead_chain.color]
      @dead_chains = Set.new([initial_dead_chain])
      @alive_chains = initial_dead_chain.all_reachable_enemy_chains
      @members = @alive_chains.dup
      @members.add(initial_dead_chain)
      @alive_chains_linked_by = { initial_dead_chain => @alive_chains.dup }

      super
      add_member_lookups(@alive_chains) # initial_dead_chain already has member lookup, thanks to super
    end

    def _stones
      @alive_chains.inject(Set.new) { |cache, chain| cache += chain.stone_tiles }
    end

    def has_dead_chain?(chain)
      @dead_chains.include?(chain)
    end

    def add_member(new_chain, params={})
      super(new_chain)

      if new_chain.color != @color
        @dead_chains.add(new_chain)
        @alive_chains_linked_by[new_chain] = new_chain.all_reachable_enemy_chains
        @alive_chains_linked_by[new_chain].each do |alive_chain|
          @members.add(alive_chain)
          add_member_lookup(alive_chain)
        end
      end

      #### I think new_chain will only ever be a chain that has been marked dead
      #else
      #  @alive_chains.add(new_chain)
      #  ### we don't know which of new_chain's reachable enemy chains are dead...
      #  ### slightly unsure about this part.. will have to review if this even needed
      #  params[:linking_dead_chains].each do |dead_chain|
      #    @alive_chains_linked_by[dead_chain].add(new_chain)
      #    @members.add(dead_chain)
      #    add_member_lookup(dead_chain)
      #  end
      #end
    end

    def territory_counts(recalculate=false)
      if @territory_counts == nil || recalculate
        @territory_counts = resulting_territory_tile_sets(include_alive_chains=true).flatten.size
      end
      @territory_counts
    end

    # are there use cases for this besides: "because it (member_chain) has been marked as dead" ??
    def remove_alive_member_chain(member_chain)
      @members.delete(member_chain)
      delete_member_lookup(member_chain)
    end

    def remove_dead_member_chain(dead_chain)
      @members.delete(dead_chain)
      @alive_chains_linked_by.delete(dead_chain)
      @dead_chains.delete(dead_chain)
      delete_member_lookup(dead_chain)
    end

    def no_longer_needed?
      @dead_chains.size == 0
    end

    # in addition to the territory tiles already existing in alive member chains
    def resulting_territory_tile_sets(include_alive_chains=false)
      tile_sets = Set.new

      @dead_chains.each do |dead_chain|
        tile_sets.add(dead_chain.stone_tiles)
        tile_sets.add(dead_chain.surrounded_tiles)
        tile_sets.add(dead_chain.neutral_tiles)

        # blargh! we are using the word 'alive' in two slightly different ways in this module
        @alive_chains_linked_by[dead_chain].each do |alive_chain|
          tile_sets.add(alive_chain.surrounded_tiles) if alive_chain.not_alive? || include_alive_chains
        end
      end

      tile_sets
    end
  end

end
