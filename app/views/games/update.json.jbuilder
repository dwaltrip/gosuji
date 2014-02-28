# makes use of two local vars, 'tiles' and 'user'
# this allows to use this template for both current_user and their opponent

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
json.undo_button_disabled (!@game.played_a_move?(user)) if @game.move_num <= 2
json.active_player (@game.active_player == user)
