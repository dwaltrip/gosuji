module Rulebook

  class Handler
    EMPTY = GoApp::EMPTY_TILE

    attr_reader :group_ids, :group_members, :liberties, :size

    def initialize(params = {})
      Rails.logger.info "-- Rulebook::Handler.initialize -- entering"

      @size = params.fetch(:size, 19)

      if params.key?(:json_board)
        @board = ActiveSupport::JSON.decode(params[:json_board])
      else
        @board = params.fetch(:board, Array.new(@size**2, 0))
      end

      @group_ids = Hash.new
      # @group_members and @liberties hashes have default values of emtpy set
      @group_members = Hash.new { |hash, key| hash[key] = Set.new }
      @liberties = Hash.new { |hash, key| hash[key] = Set.new }

      @group_count = 0
      self.build_groups

      Rails.logger.info "-- Rulebook::Handler.initialize -- exiting"
    end

    def build_groups
      Rails.logger.info "-- Rulebook::Handler.build_groups -- entering"

      (0...@size**2).each do |pos|

        up, left = up_and_left(pos)
        up_group, left_group = get_groups(up, left)

        if @board[pos] == EMPTY
          if left_group
            @liberties[left_group].add(pos)
          end
          if up_group
            @liberties[up_group].add(pos)
          end

        else
          # if same color as left stone, add to that group
          if left && (@board[pos] == @board[left])
            @group_members[left_group].add(pos)
            @group_ids[pos] = left_group
          end

          # if same color as up stone, add to that group
          if up && (@board[pos] == @board[up])

            # check if already added to left group, if so combine left group with the up group
            if left_group && @group_members[left_group].include?(pos)
              @group_members[left_group].each do |left_group_member_pos|
                @group_ids[left_group_member_pos] = up_group
              end
              @group_members[up_group] += @group_members[left_group]
              @liberties[up_group] += @liberties[left_group]

              # remove prior references to left group
              @group_members.delete(left_group)
              @liberties.delete(left_group)
              left_group = up_group
            # else just add to up group as usual
            else
              @group_members[up_group].add(pos)
              @group_ids[pos] = up_group
            end
          end

          if not @group_ids[pos]
            @group_count += 1
            @group_ids[pos] = @group_count
            @group_members[@group_count].add(pos)
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

      Rails.logger.info "-- Rulebook::Handler.build_groups -- exiting"
    end

    def up_and_left(pos)
      if pos < @size
        up = nil
      else
        up = pos - @size
      end

      if pos % 19 == 0
        left = nil
      else
        left = pos - 1
      end

      [up, left]
    end

    def get_groups(*args)
      args.map { |arg| @group_ids[arg] or nil }
    end

  end

end
