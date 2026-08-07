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

    it "est vrai quand la branche accuse du retard sans que GitHub la marque BEHIND" do
      expect(described_class.new("mergeStateStatus" => "UNSTABLE", "behindBy" => 4)).to be_needed
    end

    it "est faux quand la branche est à jour" do
      expect(described_class.new("mergeStateStatus" => "UNSTABLE", "behindBy" => 0)).not_to be_needed
    end
  end
end
