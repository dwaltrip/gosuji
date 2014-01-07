require 'spec_helper'

def setup_and_create_game
  game = create(:new_active_game)
  Board.initial_board(game)
  session[:user_id] = game.black_player.id
  game
end

describe GamesController do

  describe "ajax POST to #update" do

    context "in all cases" do

      it "redirects to login page if not logged in" do
        game = create(:new_active_game)
        Board.initial_board(game)
        xhr :post, :update, id: game

        expect(response).to redirect_to log_in_url
      end

      it "stores current game in @game" do
        game = setup_and_create_game
        xhr :post, :update, id: game

        expect(assigns(:game)).to eq(game)
      end

      # we arent passing any data in this test which might not be ideal
      # the controller should potentially not render anything if no data was passed to the update action
      it "it has status 200 and renders the javascript response: 'update.js.erb'" do
        game = setup_and_create_game
        xhr :post, :update, id: game

        expect(response.status).to eq(200)
        expect(response).to render_template(:update)
        expect(response.content_type).to eq(Mime::JS)
      end
    end

    context "when params has new_move data" do

      def setup_for_new_move
        game = setup_and_create_game
        allow(game).to receive(:new_move).and_return(true)
        allow(game).to receive(:tiles_to_render) { Hash.new }
        allow(Game).to receive(:find).and_return(game)
        game
      end

      it "calls game.new_move with correct argument" do
        game = setup_for_new_move
        xhr :post, :update, id: game, new_move: 1

        expect(game).to have_received(:new_move).with(1, anything())
      end

      it "publishes new move data to NodeJS server via redis (for websocket updating)" do
        game = setup_for_new_move
        allow($redis).to receive(:publish)
        xhr :post, :update, id: game, new_move: 2

        expect($redis).to have_received(:publish).once
      end
    end

  end

end
