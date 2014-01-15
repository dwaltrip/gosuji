require 'spec_helper'

require 'rspec/expectations'
RSpec::Matchers.define :have_image do |img_src, options|
  options = options || {}
  match { |node| node.has_selector? "img[src*=#{img_src}]", options }
end


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
      expect(page).to have_image("blank_tiles", count: size**2)
      expect(page).not_to have_image("stone")
    end

    # black plays a move first, and first item in players Cycle is black player
    players.cycle(tiles.length) do |current_player, counter|
      color = game.player_color(current_player)
      move_num = counter + 1
      stone_counts[color] += 1
      tile = tiles[counter]

      # current player plays next move
      in_browser(current_player) do
        page.find(tile).click

        # consider removing this and trying without custom 'have_image' matcher
        sleep(1) # not the most elegant, but works well and don't have time to keep digging
      end

      # then both should see the updated board
      in_browsers(players) do
        # loop through old moves and verify they are being displayed properly
        Cycle.new([:black, :white]).cycle(counter) do |prev_color, inner_counter|
          prev_tile = tiles[inner_counter]

          expect(page.find(prev_tile)).to have_image("#{prev_color}_stone")
          expect(page.find(prev_tile)).not_to have_image("highlighted")
        end

        expect(page.find(tile)).to have_image("#{color}_stone_highlighted")
        expect(page).to have_image("#{color}_stone_highlighted", count: 1)
        expect(page).to have_image("#{color}_stone", count: stone_counts[color])

        expect(page).to have_image("stone", count: move_num)
        expect(page).to have_image("blank_tiles", count: size**2 - move_num)
      end
    end
  end


  # this scenario has to be run with local NodeJS app also running
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
    end
  end

end


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

