# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/report"

RSpec.describe AutomergeRenovate::Report do
  let(:pastel) { Pastel.new(enabled: false) }

  describe "#to_s" do
    it "affiche la PR fusionnée groupée sous son repo" do
      results = [
        { repo: "captive-studio/groove-application", number: 414, action: :merge, strategy: :rebase },
      ]

      output = described_class.new(results, pastel: pastel).to_s

      expect(output).to include("captive-studio/groove-application")
      expect(output).to include("✓ #414 fusionnée (rebase)")
    end

    it "affiche le rebase demandé" do
      results = [ { repo: "captive-studio/cae-application", number: 1008, action: :rebase_requested } ]

      output = described_class.new(results, pastel: pastel).to_s

      expect(output).to include("→ #1008 rebase demandé")
    end

    it "affiche la PR ignorée avec sa raison" do
      results = [
        { repo: "captive-studio/monocle", number: 42, action: :skip, reason: "automerge désactivé" },
      ]

      output = described_class.new(results, pastel: pastel).to_s

      expect(output).to include("✗ #42 ignorée : automerge désactivé")
    end

    it "affiche un total récapitulatif en bas de rapport" do
      results = [
        { repo: "r1", number: 1, action: :merge, strategy: :rebase },
        { repo: "r1", number: 2, action: :merge, strategy: :rebase },
        { repo: "r1", number: 3, action: :rebase_requested },
        { repo: "r1", number: 4, action: :skip, reason: "checks non verts" },
      ]

      output = described_class.new(results, pastel: pastel).to_s

      expect(output).to include("2 fusionnée(s), 1 rebase demandé(s), 1 ignorée(s)")
    end
  end

  describe "#summary" do
    it "expose le total sans le détail par repo, pour un affichage en direct" do
      results = [
        { repo: "r1", number: 1, action: :merge, strategy: :rebase },
        { repo: "r1", number: 2, action: :skip, reason: "checks non verts" },
      ]

      expect(described_class.new(results, pastel: pastel).summary).to eq(
        "1 fusionnée(s), 0 rebase demandé(s), 1 ignorée(s)"
      )
    end
  end

  describe ".pr_line" do
    it "formate une ligne de PR fusionnée, réutilisable pour un affichage en direct" do
      pr = { repo: "captive-studio/groove-application", number: 414, action: :merge, strategy: :rebase }

      expect(described_class.pr_line(pr, pastel: pastel)).to eq("  ✓ #414 fusionnée (rebase)")
    end
  end
end
