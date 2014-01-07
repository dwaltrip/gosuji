
FactoryGirl.define do

  factory :user do
    sequence(:username) { |n| "foo#{n}" }
    password "secret"
    password_confirmation "secret"
  end

  factory :game do
    description "fun game"
    association :creator, factory: :user
    status Game::OPEN
    board_size GoApp::BOARD_SIZE

    trait :finished do
      status Game::FINISHED
    end

    trait :active do
      status Game::ACTIVE
    end

    factory :new_active_game, traits: [:active] do
      association :black_player, factory: :user
      association :white_player, factory: :user
    end
  end

end
