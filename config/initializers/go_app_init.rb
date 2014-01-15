# load files from lib directory
Dir[Rails.root + 'lib/**/*.rb'].each do |file|
  require file
end

# compute the star points for each board size once
# then reference as app constants
GoApp::BOARD_SIZES.each do |size|
  GoApp::STAR_POINTS[size] = StarPoints::positions_for_board_size(size)
end

letters = ("a".."h").to_a + ("j".."z").to_a

GoApp::MAX_BOARD_SIZE.times do |n|
  label = ""
  # add a prefix once we run out of letters
  if n >= letters.length
    label << letters[(n / letters.length) - 1]
  end
  label << letters[n % letters.length]

  GoApp::COLUMN_LABELS << label
end
