# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/rebase_need"

RSpec.describe AutomergeRenovate::RebaseNeed do
  describe "#needed?" do
    it "est vrai quand GitHub marque la branche en retard sur sa base" do
      expect(described_class.new("mergeStateStatus" => "BEHIND")).to be_needed
    end

    it "est vrai quand la branche est en conflit" do
      expect(described_class.new("mergeStateStatus" => "DIRTY")).to be_needed
    end

    it "est faux pour une branche fusionnable telle quelle, même en retard" do
      expect(described_class.new("mergeStateStatus" => "UNSTABLE")).not_to be_needed
    end
  end
end
