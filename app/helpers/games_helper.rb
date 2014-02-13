module GamesHelper

  BASE = ActionController::Base.new()

  def disable_turn_actions?(game)
    current_user != game.active_player
  end

  def board_size_options
    options_for_select(
      (GoApp::MIN_BOARD_SIZE..GoApp::BOARD_SIZE).to_a,
      [GoApp::BOARD_SIZE]
    )
  end

  def move_status_message(game)
    board = game.active_board

    msg = ""
    if game.move_num == 0
      msg << "Game Start"
    else
      msg << "Move #{game.move_num}"
      msg << " (#{game.player_color(game.inactive_player).capitalize[0]}"

      if board.pos
        col_num = board.pos % game.board_size
        row_label = game.board_size - (board.pos / game.board_size)
        msg << " #{GoApp::COLUMN_LABELS[col_num]}#{row_label})"
      elsif board.pass
        msg << " pass)"
      else
        logger.info "-- GamesHelper.move_status_message -- oops, something wrong"
      end
    end

    msg << ": #{game.player_color(game.active_player).capitalize} to play"
  end

  def scoring_instructions
    BASE.render_to_string(partial: 'games/notification', locals: { sub_partial: 'games/scoring_instructions' })
  end

end
