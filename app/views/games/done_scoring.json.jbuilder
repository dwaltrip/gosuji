
if game.finished?
  json.game_finished true
  json.game_finished_message game_finished_message(game)
  json.status_message status_message(game)

else
  json.status_message "Waiting for opponent to finish"
end
