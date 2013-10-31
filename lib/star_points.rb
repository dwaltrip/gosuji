module StarPoints

  module_function

  def positions_for_board_size(size)
    edge_spacing =
      if (size > 9)
        4
      else
        3
      end
    xy_coords = [edge_spacing, size - edge_spacing + 1]

    # all boards have corner star points, but can only add middle edge points if board is odd-numbered
    if size % 2 == 1
      xy_coords << (size + 1) / 2
    end

    # use 'xy_coords' for both dimensions as the star points are completely symmetrical
    xy_coords.flat_map do |y|
      xy_coords.map do |x|
        convert_coords_to_flat_array_index(x, y, size)
      end
    end
  end

  def convert_coords_to_flat_array_index(x, y, size)
    (size * (y-1)) + x-1
  end

end
