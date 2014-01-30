require 'spec_helper'

describe ScoreKeeper do

  describe ".get_territory" do
    sk = ScoreKeeper.new

    it "returns [1]" do
      expect(sk.get_territory).to eq([1])
    end

  end

end
