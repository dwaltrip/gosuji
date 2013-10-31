# load files from lib directory
Dir[Rails.root + 'lib/**/*.rb'].each do |file|
  require file
end

# compute the star points for each board size once
# then reference as app constants
GoApp::BOARD_SIZES.each do |size|
  GoApp::STAR_POINTS[size] = StarPoints::positions_for_board_size(size)
end
