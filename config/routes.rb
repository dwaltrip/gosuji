GoApp::Application.routes.draw do

  root :to => redirect('/games')

  get "log_in" => "sessions#new", :as => "log_in"
  get "log_out" => "sessions#destroy", :as => "log_out"
  resources :sessions

  get "sign_up" => "users#new", :as => "sign_up"
  resources :users, :only => [:new, :create, :show]

  resources :games do
    member do
      post :join
      post :new_move
      post :pass_turn
      post :undo_turn
      post :request_undo
      post :mark_stones
      post :done_scoring
    end
  end

end
