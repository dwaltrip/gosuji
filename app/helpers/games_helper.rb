module GamesHelper

  class TilePresenter
    attr_accessor :is_star_point, :is_most_recent_move, :is_ko, :is_invalid_move

    def initialize(params)
      @board_size = params[:board_size]
      @state = params[:state]
      @pos = params[:pos]
      @viewer = params[:viewer]

      @is_star_point = false
      @is_most_recent_move = false
      @is_ko = false
      @is_invalid_move = false
    end

    def display_image_path
      "#{display_image_dir}/#{display_image_filename}.png"
    end

    def preview_stone_path
      "#{GamesHelper.base_dir}/#{@viewer.color}_stone_preview.png"
    end

    def alt_text
      "#{display_image_filename.gsub('_', ' ')} tile"
    end

    def not_clickable?
      (@viewer.type != :active_player) or (not playable?)
    end

    def has_preview_stone?
      (@viewer.type != :observer) and playable?
    end

    def on_left_side?
      @pos % @board_size == 0
    end

    def on_right_side?
      (@pos + 1) % @board_size == 0
    end


    private

    def display_image_dir
      dir = GamesHelper.base_dir

      if is_ko?
        dir << '/ko_marker_tiles'
      elsif is_empty?
        dir << '/blank_tiles'
      end

      dir
    end

    def display_image_filename
      filename_chunks = []

      if is_empty?
        if is_star_point?
          filename_chunks << 'star_point'
        elsif in_center?
          filename_chunks << 'center'
        else
          if on_bottom_side?
            filename_chunks << 'bottom'
          elsif on_top_side?
            filename_chunks << 'top'
          end

          if on_left_side?
            filename_chunks << 'left'
          elsif on_right_side?
            filename_chunks << 'right'
          end
        end
      else
        if has_black_stone?
          filename_chunks << 'black_stone'
        elsif has_white_stone?
          filename_chunks << 'white_stone'
        end

        if is_most_recent_move?
          filename_chunks << 'highlighted'
        end
      end

      filename_chunks.join('_')
    end

    def playable?
      is_empty? and (not is_invalid_move?) and (not is_ko?)
    end

    def is_empty?
      @state == GoApp::EMPTY_TILE
    end

    def has_black_stone?
      @state == GoApp::BLACK_STONE
    end

    def has_white_stone?
      @state == GoApp::WHITE_STONE
    end

    def on_top_side?
      @pos < @board_size
    end

    def on_bottom_side?
      @pos >= (@board_size - 1) * @board_size
    end

    def in_center?
      not (on_left_side? or on_right_side? or on_top_side? or on_bottom_side?)
    end

    def is_invalid_move?
      @is_invalid_move
    end

    def is_ko?
      @is_ko && (@viewer.type == :active_player)
    end

    def is_most_recent_move?
      @is_most_recent_move
    end

    def is_star_point?
      @is_star_point
    end

  end


  module_function

  def base_dir
    "game_board/#{tile_pixel_size}px"
  end

  # todo: don't hardcode this, use information from request to choose best size
  def tile_pixel_size
    29
  end

end
