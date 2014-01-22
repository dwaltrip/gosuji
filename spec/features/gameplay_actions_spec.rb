require 'spec_helper'

# these specs need to be run with Node.js app also running
feature "gameplay actions" do

  scenario "players play several basic moves back and forth" do
    size = GoApp::MIN_BOARD_SIZE
    players, game = setup_game_and_sessions(board_size: size)

    tiles = [
      "#tile-#{size + 1}",
      "#tile-#{2 * size - 2}",
      "#tile-#{4 * size - 2}",
      "#tile-#{3 * size + 1}"
    ]
    stone_counts = { black: 0, white: 0 }

    # ensure both players have blank game boards to start
    in_browsers(players) do |player|
      expect(page).to have_blank_tile(count: size**2)
      expect(page).not_to have_stone
    end

    # alternate between black and white player, playing a move, and assert browser displays board properly
    players.cycle(tiles.length) do |current_player, counter|
      color = game.player_color(current_player)
      move_num = counter + 1
      stone_counts[color] += 1
      tile = tiles[counter]

      # current player plays next move
      in_browser(current_player) { find(tile).click }

      # expect both players to see the updated board
      in_browsers(players) do

        # loop through old moves and verify they are being displayed properly
        Cycle.new([:black, :white]).cycle(counter) do |prev_color, inner_counter|
          prev_tile = tiles[inner_counter]
          expect(find(prev_tile)).to have_stone(color: prev_color, highlighted: false)
        end

        expect(find(tile)).to have_stone(color: color, highlighted: true)
        expect(page).to have_stone(color: color, count: stone_counts[color])
        expect(page).to have_stone(highlighted: false, count: move_num - 1)
        expect(page).to have_blank_tile(count: size**2 - move_num)
        expect(page).to have_content("Move #{counter + 1}")
      end
    end
  end


  scenario "player passes their turn" do
    size = GoApp::MIN_BOARD_SIZE
    players, game = setup_game_and_sessions(board_size: size)
    first_player = game.active_player

    in_browsers(players) do |player|
      if player == first_player
        click_button "Pass"
      end
    end

    in_browsers(players) do |player|
      expect(page).to have_content("#{game.player_color(first_player).capitalize[0]} pass")
      expect(page).to have_content("Move 1")
    end
  end


  scenario "player plays move, then requests undo, and other player grants the undo" do
    size = GoApp::MIN_BOARD_SIZE
    players, game = setup_game_and_sessions(board_size: size)
    first_player = game.active_player    # this is the player who will grant the undo
    second_player = game.inactive_player # this is the player who will request an undo

    first_tile = "#tile-3"
    tile_to_undo = "#tile-13"
    tiles = { first_player.id => first_tile, second_player.id => tile_to_undo }

    # each player makes a move
    # undo should be disabled before a player makes their first move, and then enabled
    in_browsers(players) do |player|
      expect(page).not_to have_button("Undo")
      find(tiles[player.id]).click
      expect(page).to have_button("Undo")
    end

    # second player requests undo
    in_browser(second_player) do
      click_button "Undo"
    end

    # first player should see popup allowing approve/deny the request for undo
    in_browser(first_player) do
      expect(page).to have_content("has requested an undo")
      expect(find("#undo-approval-form")).to have_button("Yes")
      expect(find("#undo-approval-form")).to have_button("No")

      # approve the undo request
      find("#undo-approval-form").click_button "Yes"
    end

    # both players should now see the updated board with the most recent move reverted
    in_browsers(players) do |player|
      expect(find(first_tile)).to have_stone(color: game.player_color(first_player), highlighted: true)
      expect(find(tile_to_undo)).to have_blank_tile

      expect(page).to have_stone(count: 1)
      expect(page).to have_blank_tile(count: size**2 - 1)
      expect(page).to have_content("Move 1")
    end

    # undo should not be possible once again, as the only move made by this player was undone already
    in_browser(second_player) do
      expect(page).not_to have_button("Undo")
    end
  end

end


# helper methods to be used as natural rspec matchers, by returning calls to the macther have_selector
# this gives more useful failure messages, better use of capybara's synching/waiting abilities
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


# create game, load game in browser for both players, and make sure websockets are working
def setup_game_and_sessions(options)
  players = Cycle.new([
    create(:user, username: 'player1'),
    create(:user, username: 'player2')
  ])
  board_size = options[:board_size] || GoApp::MIN_BOARD_SIZE
  game = create_active_game(players, board_size=board_size)

  # both players visit site
  in_browsers(players) do |player|
    sign_in_as player, "secret"
    visit game_path(game)

    # wait until sockjs connection is established (unfortunately default of 2 seconds isnt always long enough..)
    page.wait_until(5) { page.evaluate_script "socket !== null && socket.protocol !== null" }
  end

  [players, game]
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

def in_browsers(players)
  players.each do |player|
    Capybara.session_name = player.username
    yield player
  end
end

def in_browser(player)
  Capybara.session_name = player.username
  yield
end


# useful for debugging
def save_page_html(current_page, suffix=nil)
  time_str = Time.now.strftime('%Y-%m-%d-%H-%M-%S-%L')

  File.open("#{Rails.root}/log/tmp/capybara/#{time_str}#{suffix.to_s}.html", "w") do |file|
    file.write(current_page.html)
  end
end


# yes, creating this class for use in the feature specs is slight overkill
# but I got to learn about fibers, it is elegant to use, and it was fun to make =)
class Cycle
  def initialize(enum)
    @enum = enum
  end

  # repeats @enum.each until until 'n' total iterations
  # differs from built-in Enumerable.cycle in that 'n' represents number of items accessed,
  # not number of times we loop through the enumerable
  def cycle(n)
    restart
    n.times { |i| yield @fiber.resume, i }
  end

  def restart
    @fiber = Fiber.new do
      @enum.each { |item| Fiber.yield item } while true
    end
  end

  def each
    @enum.each { |item| yield item }
  end

  def to_a; @enum; end
end
