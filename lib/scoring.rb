
module Scoring

  EMPTY = GoApp::EMPTY_TILE
  BLACK = GoApp::BLACK_STONE
  WHITE = GoApp::WHITE_STONE
  STONES = [BLACK, WHITE]

  COLORS = { BLACK => :black, WHITE => :white }

  # this class doesn't do anything yet
  class Scorebot

    def initialize(params)
      #@size = params[:size]
      #@board = params[:board]

      @board = BoardAnalyzer.new(size: params[:size], board: params[:board])
      @redis_key = params[:redis_key]

      unpack_data
    end

    def unpack_data
      data = $redis.get(@redis_key) || {}
      @first_time = data[:first_time] || true

      # convert from json to ruby
    end

    def changed_tiles
      if @first_time
        @board.analyze

        #@group_manager.build_groups

        # store in redis
      else
        my_str = 'foo bar'
      end
    end
  end


  class BoardAnalyzer

    def initialize(params)
      @size = params[:size]
      @board = params[:board]
      @manager = ContainerManager.new(board_analyzer: self)

      analyze(params[:cached_analysis])
    end

    def stone_groups
      @manager.stone_groups
    end

    def territories
      @manager.territories
    end

    def analyze(cached_analysis=nil)
      if cached_analysis
        # read data and populate objects - hah!

      else
        tiles_positions.each do |pos|
          add_new_member_to_board_groups(pos)
          update_container_neighbor_data(pos)
        end
      end
    end

    def add_new_member_to_board_groups(new_pos)
      already_processed_neighboring_tiles(new_pos).each do |neighbor_pos|
        if same_tile_types(new_pos, neighbor_pos)
          if has_container?(new_pos)
            merge_containers(new_pos, neighbor_pos)
          else
            find_container(neighbor_pos).add_member(new_pos)
          end
        end
      end

      # if neighbors are not of same type, create new group
      create_container(new_pos) unless has_container?(new_pos)
    end

    # the writing of this method was when i started mixing the term 'group' with 'container'
    # sigh.. naming things is a pain the ass. can't decide what term is best
    def update_container_neighbor_data(pos)
      group = find_container(pos)

      already_processed_neighboring_tiles(pos).each do |neighbor_pos|
        neighboring_group = find_container(neighbor_pos)

        unless same_tile_types(pos, neighbor_pos)
          group.add_neighbor(neighboring_group)
          neighboring_group.add_neighbor(group)
        end

        # add liberties to stone groups
        if has_stone?(pos) && is_empty?(neighbor_pos)
          group.add_liberty(neighbor_pos)
        elsif is_empty?(pos) && has_stone?(neighbor_pos)
          neighboring_group.add_liberty(pos)
        end
      end
    end

    def find_container(pos)
      @manager.find_owner(pos)
    end

    def has_container?(pos)
      @manager.has_owner?(pos)
    end

    def find_containers(*positions)
      positions.map { |pos| find_container(pos) }
    end

    def create_container(pos)
      @manager.create_container(pos, tile_state: tile_state(pos))
    end

    def merge_containers(pos1, pos2)
      @manager.merge_containers(pos1, pos2)
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

    def tile_state(pos)
      @board[pos]
    end

    # as we scan board and construct data structures for score analysis,
    # we only look up at neighbors above and to the left of each tile which,
    # due to the iteration pattern (from top left to bottom right), have already been processed
    def already_processed_neighboring_tiles(pos)
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
  end


  class ContainerManager

    def initialize(params)
      @board_analyzer = params[:board_analyzer]
      @instance_counts = Hash.new(0)

      @instances      = Hash.new { |h, k| h[k] = {} }
      @owners         = Hash.new { |h, k| h[k] = {} }
      @assimilations  = Hash.new { |h, k| h[k] = {} }
    end

    def stone_groups
      instances(StoneGroup.class_key).values
    end

    def territories
      instances(Territory.class_key).values
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

    def add_member_lookup(member_key, container_instance)
      owners(container_instance.class_key)[member_key] = container_instance.instance_id
    end

    def instances(class_key)
      @instances[class_key]
    end

    def owners(class_key)
      @owners[class_key]
    end

    # whenever two groups merge, one assimilates the other
    # we redirect the old id to the assmimilator's id, so member lookups will return correct container instance
    def assimilations(class_key)
      @assimilations[class_key]
    end

    def has_owner?(member_key)
      class_key = container_class(member_key).class_key
      owners(class_key).key?(member_key)
    end

    def find_owner(member_key)
      class_key = container_class(member_key).class_key
      owner_id = owners(class_key)[member_key]
      fetch_inst_or_assimilator_inst(owner_id, class_key)
    end

    def fetch_inst_or_assimilator_inst(instance_id, class_key)
      assimilator_id = instance_id
      _assimilations = assimilations(class_key)

      if _assimilations.key?(assimilator_id)
        # this loop might not be necessary, we might be able to handle it whenever a merge occurs
        # there might have been several assimilations (merges), loop through to get the most recent one
        assimilator_id = _assimilations[assimilator_id] while _assimilations.key?(assimilator_id)

        # update hash so original instance_id points directly to the instance_id of the most recent assimilator
        _assimilations[instance_id] = assimilator_id
      end

      instances(class_key)[assimilator_id]
    end

    def merge_containers(member_key1, member_key2)
      smaller, larger = order_by_size(find_owner(member_key1), find_owner(member_key2))
      class_key = smaller.class_key

      # dont merge if they are the same
      unless smaller.instance_id == larger.instance_id
        assimilations(class_key)[smaller.instance_id] = larger.instance_id

        larger.add_members(smaller.members)
        update_neighbors_during_merge(larger, smaller)

        larger.assimilate(smaller)
        remove_container(smaller)
      end
    end

    def order_by_size(*containers)
      containers.sort { |a,b| a.size <=> b.size }
    end

    # does this belong here in the manager class??
    def update_neighbors_during_merge(assimilator, assimilated)
      assimilated.all_neighbor_types.each do |type, set_of_neighbors|
        set_of_neighbors.each { |neighbor| neighbor.replace_neighbor(assimilated, assimilator) }
        assimilator.neighbors_of_type(type).merge(set_of_neighbors)
      end
    end

    def container_class(member_key)
      if member_key.class == Fixnum
        if @board_analyzer.is_empty?(member_key)
          Territory
        else
          StoneGroup
        end
      end
    end

    def print_data
      Rails.logger.info "\n===== ContainerManager.print_data ===== START\n"
      [:@instances, :@owners, :@assimilations].each do |var_name|
        Rails.logger.info "=== #{var_name} ==="
        instance_variable_get(var_name).each do |inst_type, inst_hash|
          Rails.logger.info "--- inst_type: #{inst_type} ---"
          inst_hash.each do |inst_id, inst|
            Rails.logger.info "  #{inst_id} => #{inst.inspect}"
          end
        end
      end
      Rails.logger.info "===== ContainerManager.print_data ===== END\n"
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
      @manager.add_member_lookup(initial_member_key, self)
    end

    # sub-classes should create a '@members' Set
    def add_member(new_member)
      @members.add(new_member)
      @manager.add_member_lookup(new_member, self)
    end

    def add_members(new_members)
      @members.merge(new_members)
    end

    def size
      @members.size
    end

    # sub-classes need to have a '@neighbors' hash. keys: container type, valus: set of container instances
    # might change so that -- values: set of container instance_ids
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
      remove_neighbor(old_neighbor)
      add_neighbor(new_neighbor)
    end

    # these two methods 'add_neighbor' and 'remove_neighbor' expect base classes to have a '@neighbors' hash
    # and to implement the 'neighbor_type' method
    def add_neighbor(neighboring_container)
      type = neighbor_type(neighboring_container)
      @neighbors[type].add(neighboring_container)
    end

    def remove_neighbor(neighboring_container)
      type = neighbor_type(neighboring_container)
      @neighbors[type].delete(neighboring_container)
    end

    def inspect(params = {})
      # dont print @neighbors by default, makes the output easier to read. never print @manager
      skip = params.fetch(:skip, [:@neighbors]).concat([:@manager])

      inspected_vars = instance_variables.map do |var|
        "#{var}=#{instance_variable_get(var).inspect}" unless skip.include?(var)
      end

      "#<#{self.class}:0x%x %s>" % [object_id * 2, inspected_vars.compact.join(", ")]
    end
  end


  class Territory < Container

    def initialize(initial_tile_pos, params={})
      @members = Set.new([initial_tile_pos])
      @neighbors = { black_groups: Set.new, white_groups: Set.new }

      super
    end

    def tiles
      @members
    end

    def neighboring_black_groups
      @neighbors[:black_groups]
    end

    def neighboring_white_groups
      @neighbors[:white_groups]
    end

    def neighbor_type(stone_group)
      if stone_group.color == BLACK
        :black_groups
      elsif stone_group.color == WHITE
        :white_groups
      end
    end
  end

  class StoneGroup < Container
    attr_reader :color, :liberties

    def initialize(initial_stone_pos, params={})
      @members = Set.new([initial_stone_pos])
      @liberties = Set.new
      @color = params[:tile_state]
      @neighbors = { enemy_groups: Set.new, territories: Set.new }

      super
    end

    def stones
      @members
    end

    def add_liberty(tile_pos)
      liberties.add(tile_pos)
    end

    def assimilate(other_group)
      @liberties.merge(other_group.liberties)
    end

    def neighboring_enemy_groups
      @neighbors[:enemy_groups]
    end

    def neighboring_territories
      @neighbors[:territories]
    end

    def neighbor_type(stone_group_or_territory)
      (:territories if stone_group_or_territory.class == Territory) || :enemy_groups
    end
  end


  class Chain
    def initialize(params)
      @color = params[:color]
      @groups = Set.new
    end

  end

end
