module GamesHelper

  def board_size_options
    options_for_select(
      (GoApp::MIN_BOARD_SIZE..GoApp::BOARD_SIZE).to_a,
      [GoApp::BOARD_SIZE]
    )
  end

end
