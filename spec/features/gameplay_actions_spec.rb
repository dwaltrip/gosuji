require 'spec_helper'

feature "gameplay actions" do

  # this scenario has to be run with local NodeJS app also running
  scenario "player passes their turn" do
    players = [create(:user, username: 'player1'), create(:user, username: 'player2')]

    game = create_active_game(*players)
    first_player_to_move = game.active_player
    passing_player = nil

    # both players visit site
    players.each do |player|
      in_browser(player.username) do
        sign_in_as player, 'secret'
        visit game_path(game)

        # wait until sockjs connection is established (unfortunately default of 2 seconds isnt always long enough..)
        page.wait_until(5) { page.evaluate_script "socket !== null && socket.protocol !== null" }
      end
    end

    # then active player passes
    players.each do |player|
      in_browser(player.username) do
        if player == first_player_to_move
          click_button "Pass"
        else
          passing_player = player
        end
      end
    end

    # then both should see the result
    players.each do |player|
      in_browser(player.username) do
        # this should be a more focused search in the 'game score/status/last move played' area
        expect(page).to have_content("#{game.player_color(first_player_to_move).capitalize[0]} pass")
      end
    end
  end

end

def in_browser(name)
  Capybara.session_name = name

  yield
end

def sign_in_as(user, password)
  visit log_in_path
  fill_in 'username', with: user.username
  fill_in 'password', with: password
  click_button 'Log in'
end

def create_active_game(player1, player2)
  game = create(:new_active_game, black_player: player1, white_player: player2)
  Board.initial_board(game)
  game
end
