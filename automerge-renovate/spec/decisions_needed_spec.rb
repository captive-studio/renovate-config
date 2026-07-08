# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/decisions_needed"

RSpec.describe AutomergeRenovate::DecisionsNeeded do
  let(:pastel) { Pastel.new(enabled: false) }

  describe "#to_s" do
    it "retourne une chaîne vide quand aucune PR ne nécessite de décision" do
      results = [ { repo: "r1", number: 1, action: :merge, strategy: :rebase } ]

      expect(described_class.new(results, pastel: pastel).to_s).to eq("")
    end

    it "liste les PR à checks verts mais automerge désactivé, avec leur lien" do
      results = [
        { repo: "r1", number: 1, action: :merge, strategy: :rebase },
        { repo: "r1", number: 42, action: :skip, reason: "automerge désactivé", needs_decision: true,
          url: "https://github.com/captive-studio/monocle/pull/42", },
      ]

      output = described_class.new(results, pastel: pastel).to_s

      expect(output).to include("Décisions à prendre")
      expect(output).to include("https://github.com/captive-studio/monocle/pull/42")
    end
  end
end
