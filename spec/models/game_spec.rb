require 'spec_helper'

describe Game do
  let(:game) { Game.new }

  it "has a description with no more than 40 characters" do
    game.should be_valid
    game.description = "super duper more than 40 character long descriptive piece of text"
    game.should_not be_valid
  end

end
