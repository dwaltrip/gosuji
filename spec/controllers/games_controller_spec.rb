require 'spec_helper'

def setup_and_create_game
  game = create(:new_active_game)
  Board.initial_board(game)
  session[:user_id] = game.active_player.id
  game
end

def setup_for_game_action(action_type)
  game = setup_and_create_game

  allow(Game).to receive(:find).and_return(game)
  allow(JSON).to receive(:parse).and_return({ fake_data: "for you!" })
  allow($redis).to receive(:publish)

  allow(game).to receive(:tiles_to_render) { Hash.new }
  allow(game).to receive(action_type).and_return(true)

  game
end

describe GamesController do

  # finish this sometime
  # right now isnt what we want, only the last 4 actions are xhr
  #context "if the user is not logged in" do
  #  Action = Struct.new(:method, :name, :params)
  #  actions = [
  #    Action.new(:get, :index),
  #    Action.new(:get, :show, { id: 1 }),
  #    Action.new(:get, :join, { id: 1 }),
  #    Action.new(:post, :new_move, { id: 1 }),
  #    Action.new(:post, :pass_turn, { id: 1 }),
  #    Action.new(:post, :undo_turn, { id: 1 }),
  #    Action.new(:post, :request_undo, { id: 1 })
  #  ]
  #  actions_that_dont_redirect = [:index]

  #  actions.each do |action|
  #    desc = "#{action.name.inspect} redirects to login"

  #    it "redirects requests for #{action.inspect} to login page, if not logged in" do
  #      game = create(:new_active_game)
  #      Board.initial_board(game)
  #      params = action.params || {}
  #      xhr action.method, action.name, params

  #      expect(response).to redirect_to log_in_url
  #    end
  #  end
  #end

  context "#new_move" do
    it "calls game.new_move with correct parameters" do
      game = setup_for_game_action(:new_move)
      current_player = game.active_player
      xhr :post, :new_move, id: game, new_move: 1

      expect(game).to have_received(:new_move).with(1, current_player)
    end

    it "publishes game update data to NodeJS server via redis (for websocket updating)" do
      game = setup_for_game_action(:new_move)
      #allow($redis).to receive(:publish)
      xhr :post, :new_move, id: game, new_move: 2

      expect($redis).to have_received(:publish).once
    end

    it "responds with status code 200 and JSON mime type" do
      game = setup_for_game_action(:new_move)
      xhr :post, :new_move, id: game, new_move: 1

      expect(response.status).to eq(200)
      expect(response.content_type).to eq(Mime::JSON)
    end
  end

  context "#pass_turn" do
    it "calls game.pass with correct parameters" do
      game = setup_for_game_action(:pass)
      current_player = game.active_player
      xhr :post, :pass_turn, id: game

      expect(game).to have_received(:pass).with(current_player)
    end

    it "publishes game update data NodeJS server via redis (for websocket updating)" do
      game = setup_for_game_action(:pass)
      #allow($redis).to receive(:publish)
      xhr :post, :pass_turn, id: game

      expect($redis).to have_received(:publish).once
    end

    it "responds with status code 200 and JSON mime type" do
      game = setup_for_game_action(:pass)
      xhr :post, :pass_turn, id: game

      expect(response.status).to eq(200)
      expect(response.content_type).to eq(Mime::JSON)
    end
  end

end
