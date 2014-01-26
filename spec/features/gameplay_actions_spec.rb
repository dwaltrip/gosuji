require 'spec_helper'

# these specs need to be run with Node.js app also running
feature "gameplay actions" do

  scenario "players play several basic moves back and forth" do
    players, game, color_map = setup_game_and_sessions
    size = game.board_size

    tiles = [(size + 1), (2 * size - 2), (4 * size - 2), (3 * size + 1)].map { |n| selector_for_tile(n) }
    stone_counts = { black: 0, white: 0 }

    # ensure both players have blank game boards to start
    as(players) do |player|
      expect(page).to have_blank_tile(count: size**2)
      expect(page).not_to have_stone
    end

    # alternate between black and white player, playing a move, and assert browser displays board properly
    Cycle.new(players).cycle(tiles.length) do |current_player, counter|
      color = color_map[current_player.id]
      move_num = counter + 1
      stone_counts[color] += 1
      tile = tiles[counter]

      # current player plays next move. expect ajax request
      as(current_player) do
        expect{ find(tile).click }.to change{ active_ajax_requests }.by(1)
      end

      # expect both players to see the updated game
      as(players) do
        # loop through old moves and verify they are being displayed properly
        Cycle.new([:black, :white]).cycle(counter) do |prev_color, inner_counter|
          prev_tile = tiles[inner_counter]
          expect(find(prev_tile)).to have_stone(color: prev_color, highlighted: false)
        end

        expect(find(tile)).to have_stone(color: color, highlighted: true)
        expect(page).to have_stone(color: color, count: stone_counts[color])
        expect(page).to have_stone(highlighted: false, count: move_num - 1)
        expect(page).to have_blank_tile(count: size**2 - move_num)
        expect(page).to have_status_message(move_number: counter + 1)
      end

      # after playing a move, nothing should happen when current_player clicks a tile
      as(current_player) do
        expect(page).not_to have_clickable_tile

        all_tiles(size).each do |tile|
          expect{ find(tile).click }.to change{ active_ajax_requests }.by(0) # expect no ajax request
        end
      end
    end
  end


  scenario "player passes their turn" do
    players, game, color_map = setup_game_and_sessions
    size = game.board_size
    player1, player2 = players
    tile = selector_for_tile(1)

    # first player makes a move
    as(player1) do
      find(tile).click
      expect(page).not_to have_button("Pass")
    end

    # second player passes their turn. expect ajax request
    as(player2) { expect{ click_button "Pass" }.to change{ active_ajax_requests }.by(1) }

    as(players) do |player|
      expect(page).to have_status_message(pass: true, color: color_map[player2.id])
      expect(page).to have_status_message(move_number: 2)
      expect(find(tile)).to have_stone(highlighted: false) # last played stone shouldn't be highlighted
    end

    # it is now player1's turn, so turn actions should be enabled
    as(player1) do
      expect(page).to have_button("Pass")
      expect(page).to have_clickable_tile(count: size**2 - 1)
    end

    # player2 should not be able to perform turn actions
    as(player2) do
      expect(page).not_to have_button("Pass")
      expect(page).not_to have_clickable_tile

      all_tiles(size).each do |tile|
        expect{ find(tile).click }.to change{ active_ajax_requests }.by(0) # expect no ajax request
      end
    end
  end


  scenario "player plays move, then requests undo, and other player approves the undo" do
    players, game, color_map = setup_game_and_sessions
    size = game.board_size

    player1, player2 = players
    opponent = { player1.id => player2, player2.id => player1 }
    tiles = [selector_for_tile(3), selector_for_tile(11), selector_for_tile(19)]

    # cycle through tile array, alternating moves between black player & white player
    # undo should be disabled before a player makes their first move, after that enabled
    Cycle.new(players).cycle(tiles.length) do |player, counter|
      as(player) do
        expect(page).not_to have_button("Undo") if counter <= 1
        find(tiles[counter]).click
        expect(page).to have_button("Undo")
      end
    end

    as(players) { expect(page).to have_status_message(move_number: tiles.length) }

    # player1 has had two turns, player2 has had one turn
    # both now request undo, with player2 going first
    # undo for player2 reverts two moves (move 2 & 3) -- undo for player1 reverts one move (move 1)
    players.reverse_each do |requester|
      approver = opponent[requester.id]
      reverted_tile_count = if (requester == player2) then 2 else 1 end

      # make the undo request. expect an ajax request
      as(requester) { expect{ click_button "Undo" }.to change{ active_ajax_requests }.by(1) }

      # other player should see popup modal allowing the approve/denial of the undo request
      as(approver) do
        expect(undo_modal).to have_content("has requested an undo")
        expect(undo_modal).to have_button("Yes")
        expect(undo_modal).to have_button("No")

        # approve the undo request. expect an ajax request
        expect{ undo_modal.click_button "Yes" }.to change{ active_ajax_requests }.by(1)
      end

      # remove undone moves from tiles array and store in reverted_tiles
      reverted_tiles = Array.new(reverted_tile_count) { tiles.pop }

      # both players should now see the updated board, reverted to before requester's last move
      as(players) do |player|
        expect(page).to have_status_message(move_number: tiles.length)
        expect(page).to have_stone(count: tiles.length)
        expect(page).to have_blank_tile(count: size**2 - tiles.length)
        reverted_tiles.each { |tile| expect(find(tile)).to have_blank_tile }

        # if there are any stones still on board, check that the most recent one is highlighted
        if tiles.length > 0
          expect(find(tiles[-1])).to have_stone(color: color_map[approver.id], highlighted: true)
        end
      end

      # approver should not be able to perform turn actions
      as(approver) do
        expect(page).not_to have_button("Pass")
        expect(page).not_to have_clickable_tile

        all_tiles(size).each do |tile|
          expect{ find(tile).click }.to change{ active_ajax_requests }.by(0) # expect no ajax request
        end
      end

      # requester should have turn actions enabled
      as(requester) do
        expect(page).to have_clickable_tile(count: size**2 - tiles.length)
        expect(page).to have_button("Pass")
      end
    end

    # undo should not be possible once again, as all moves have been reverted
    as(players) { expect(page).not_to have_button("Undo") }
  end
end


# helper methods to be used as natural rspec matchers, by returning calls to the macther have_selector
# this gives more useful failure messages, better use of capybara's synching/waiting abilities
def have_status_message(options)
  content_string =
    if options[:move_number]
      ("Game Start" if (options[:move_number] == 0)) || "Move #{options[:move_number]}"
    elsif options[:pass]
      "#{options[:color].capitalize[0]} pass"
    end

  have_content(content_string)
end

def have_blank_tile(options={})
  options[:css_class] = ".board_tile"
  have_image("blank_tile", options)
end

def have_stone(options={})
  highlighted = options.delete(:highlighted)
  img_src_chunks = [options.delete(:color), "stone", ("highlighted" if highlighted)]
  img_src = img_src_chunks.delete_if { |chunk| chunk.nil? }.join("_")

  if (highlighted == false)
    img_src << ".png"
    options[:ends_with] = true
  end
  options[:css_class] = ".board_tile"

  have_image(img_src, options)
end

def have_image(img_src, options={})
  css_class = options.delete(:css_class).to_s
  attr_matcher_type = ("^" if options.delete(:starts_with)) || ("$" if options.delete(:ends_with)) || "*"
  selector = "img[src#{attr_matcher_type}='#{img_src}']#{css_class}"

  have_selector(selector, options)
end

def have_clickable_tile(options={})
  have_selector(".clickable", options)
end


def all_tiles(size)
  (0...size**2).map { |i| selector_for_tile(i) }
end

def selector_for_tile(n)
  "#tile-#{n}"
end

def undo_modal
  find("#undo-approval-container")
end


# create game, load game in browser for both players, and make sure websockets are working
def setup_game_and_sessions(options={})
  players = [create(:user, username: 'player1'), create(:user, username: 'player2')]
  board_size = options[:board_size] || GoApp::MIN_BOARD_SIZE
  game = create_active_game(players, board_size=board_size)
  color_map = Hash[players.map { |player| [player.id, game.player_color(player)] }]

  # both players visit site
  as(players) do |player|
    sign_in_as player, "secret"
    visit game_path(game)

    # wait until sockjs connection is established (unfortunately default of 2 seconds isnt always long enough..)
    page.wait_until(5) { page.evaluate_script "socket !== null && socket.protocol !== null" }
  end

  [players, game, color_map]
end

def create_active_game(players, size=GoApp::BOARD_SIZE)
  player1, player2 = *players
  game = create(:new_active_game, black_player: player1, white_player: player2, board_size: size)
  Board.initial_board(game)

  game
end


def sign_in_as(user, password)
  visit log_in_path
  fill_in 'username', with: user.username
  fill_in 'password', with: password
  click_button 'Log in'
end

def as(player_or_players)
  # use in_browser if just one player, otherwise use in_browsers
  _method = (:in_browsers if player_or_players.respond_to?(:each)) || :in_browser
  send(_method.to_sym, player_or_players) { |*args| yield *args }
end

def in_browsers(players)
  players.each_with_index do |player, index|
    in_browser(player) { yield player, index }
  end
end

def in_browser(player)
  Capybara.session_name = player.username
  yield
end


def active_ajax_requests
  evaluate_script("$.active")
end

# useful for debugging
def save_page_html(current_page, options={})
  filepath = "#{tmp_base_path}/#{timestamp}#{options[:suffix]}"

  File.open("#{filepath}.html", "w") do |file|
    page_html = current_page.html
    page_html.gsub! "/assets", "assets"
    file.write(page_html)
  end

  if options[:screenshot]
    current_page.save_screenshot("#{filepath}.png", full: true)
  end
end

def tmp_base_path
  "#{Rails.root}/log/tmp/capybara"
end
def timestamp
  Time.now.strftime('%Y-%m-%d-%H-%M-%S-%L')
end


# allows us to cycle through an array 'n' times, on the item level
# the built-in Enumerable.cycle just repeates the entire array 'n' times, not what I want
# Ex: Cycle.new([1, 2, 3]).cycle(5) -> 1, 2, 3, 1, 2
# as an aside, Fibers are cool
class Cycle < Array
  def cycle(n)
    restart
    n.times { |i| yield @fiber.resume, i }
  end

  def restart
    @fiber = Fiber.new do
      self.each { |item| Fiber.yield item } while true
    end
  end
end
