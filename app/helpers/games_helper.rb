module GamesHelper

  RENDERER = ActionController::Base.new()

  def disable_turn_actions?(game)
    current_user != game.active_player
  end

  def board_size_options
    options_for_select(
      (GoApp::MIN_BOARD_SIZE..GoApp::BOARD_SIZE).to_a,
      [GoApp::BOARD_SIZE]
    )
  end

  def status_message(game)
    board = game.active_board

    msg = ""
    if game.move_num == 0
      msg << "Game Start"

    elsif game.finished?
      msg << "Game Over: #{final_result_message_short(game)}"

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
        logger.info "-- GamesHelper.status_message -- oops, something wrong"
      end
    end

    msg << ": #{game.player_color(game.active_player).capitalize} to play" unless game.finished?
    msg
  end

  def scoring_instructions
    content_str = [
      "The game has entered the scoring phase.",
      "Please identify which stone groups are dead by clicking on them.",
      "You can mark a stone group as not dead by clicking on it while holding the <code>SHIFT</code> key.",
      "When finished, press the 'Done' button."
    ].join(" ")
    RENDERER.render_to_string(partial: 'games/notification', locals: { lines_of_content: [content_str] })
  end

  def game_finished_message(game)
    lines_of_content = [
      "The game is over.",
      (score_details_message(game, game.white_player) if game.win_by_score?),
      (score_details_message(game, game.black_player) if game.win_by_score?),
      "Final result: #{final_result_message(game)}"
    ].compact

    Rails.logger.info "--- GamesHelper.game_finished_message -- lines_of_content: #{lines_of_content.inspect}"
    RENDERER.render_to_string(partial: 'games/notification', locals: { lines_of_content: lines_of_content })
  end

  def score_details_message(game, player)
    details_message = "Score for #{game.player_color(player)}: "
    details_message << game.point_details(player).map { |type, points| "#{prettify(points)} #{type}" }.join(" + ")
    details_message << " = #{prettify(game.point_count(player))}"
  end

  def final_result_message(game)
    msg = ""
    if game.tie?
      msg << "tie game."
    else
      winner = game.winner
      loser = game.opponent(winner)

      if game.win_by_resign?
        msg << "#{loser.username} (#{game.player_color(loser)}) has resigned."
        msg << " #{winner.username} (#{game.player_color(winner)}) has won."
      elsif game.win_by_time?
        msg << "#{loser.username} (#{game.player_color(winner)}) ran out of time."
        msg << " #{winner.username} (#{game.player_color(winner)}) has won."
      else
        msg << "#{winner.username} (#{game.player_color(winner)}) has won by #{prettify(game.point_difference)} points."
      end
    end

    msg
  end

  def final_result_message_short(game)
    msg = ""
    if game.tie?
      msg << "Tie"
    elsif game.finished?
      winner = game.winner
      loser = game.opponent(game.winner)
      msg << "#{game.player_color(winner).capitalize[0]}+"
      msg << (("R" if game.win_by_resign?) || ("time" if game.win_by_time?) || "#{prettify(game.point_difference)}")
    end
    msg
  end

  def prettify(float)
    (float.to_i if float.to_i == float) || float
  end

end
