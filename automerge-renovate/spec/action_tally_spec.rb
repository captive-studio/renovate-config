# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/action_tally"

RSpec.describe AutomergeRenovate::ActionTally do
  describe "#to_s" do
    it "compte les fusionnées, rebase demandés et ignorées" do
      results = [
        { action: :merge },
        { action: :merge },
        { action: :rebase_requested },
        { action: :skip },
      ]

      expect(described_class.new(results).to_s).to eq("2 fusionnée(s), 1 rebase demandé(s), 1 ignorée(s)")
    end
  end
end
