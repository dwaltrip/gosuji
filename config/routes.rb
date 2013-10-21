GoApp::Application.routes.draw do

  root :to => redirect('/games')

  get "log_in" => "sessions#new", :as => "log_in"
  get "log_out" => "sessions#destroy", :as => "log_out"
  resources :sessions

  get "sign_up" => "users#new", :as => "sign_up"
  resources :users, :only => [:new, :create, :show]

  post 'games/:id', to: 'games#update_board'
  resources :games do
    member do
      get :join
    end
  end

end
