require 'spec_helper'

feature "games index" do

  scenario "user views list of open games" do
    open_games = create_list(:game, 2, description: "open game")
    closed_games = create(:game, :finished, description: "finished game")

    visit games_path
    expect(page).to have_content("Open Games")

    expect(page).to have_content("open game")
    expect(page).to have_css("table tr td:first-child", count: 2)
    expect(page).not_to have_content("finished game")
  end

end
