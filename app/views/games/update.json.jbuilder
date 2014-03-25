json.status_message status_message(@game)
json.captures do
  json.black @game.black_capture_count
  json.white @game.white_capture_count
end

json.tiles tiles do |tile|
  json.pos tile.pos
  json.classes tile.container_classes
  json.image_src image_path(tile.display_image_path)
end

# after move 1 and move 2 are the only times that the undo button disabled status is affected
json.undo_button_disabled (!player.played_a_move?) if @game.move_num <= 2
json.active_player player.their_turn?
