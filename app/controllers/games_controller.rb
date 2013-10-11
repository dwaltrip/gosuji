class GamesController < ApplicationController
  before_filter :require_login, :except => :index

  def index
    @open_games = Game.open.order('created_at DESC')
  end

  def new
  end

  def create
    new_game = Game.new(description: params[:description], status: 0, creator: current_user)
    if new_game.save
      redirect_to games_path, notice: 'Game was created successfully!'
    elsif
      redirect_to new_game_path, alert: new_game.errors.full_messages.to_sentence
    end
  end

end
