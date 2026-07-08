# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/progress_printer"

RSpec.describe AutomergeRenovate::ProgressPrinter do
  subject(:progress) { described_class.new(pastel: Pastel.new(enabled: false), out: out) }

  let(:out) { StringIO.new }

  describe "#searching" do
    it "affiche un message de recherche du ticket Jira" do
      progress.searching

      expect(out.string).to include("Recherche du ticket Jira")
    end
  end

  describe "#ticket_found" do
    it "affiche la clé du ticket trouvé" do
      progress.ticket_found("FAC-2514")

      expect(out.string).to include("FAC-2514 trouvé")
    end
  end

  describe "#repos_found" do
    it "affiche le nombre de repos à traiter" do
      progress.repos_found(17)

      expect(out.string).to include("17 repo(s)")
    end
  end

  describe "#repo" do
    it "affiche le nom du repo en cours de traitement" do
      progress.repo("captive-studio/groove-application")

      expect(out.string).to include("captive-studio/groove-application")
    end
  end

  describe "#result" do
    it "affiche la ligne de résultat d'une PR traitée" do
      progress.result({ repo: "r1", number: 414, action: :merge, strategy: :rebase })

      expect(out.string).to include("✓ #414 fusionnée (rebase)")
    end
  end

  describe "#summary" do
    it "affiche le total récapitulatif final" do
      progress.summary([ { repo: "r1", number: 1, action: :merge, strategy: :rebase } ])

      expect(out.string).to include("1 fusionnée(s), 0 rebase demandé(s), 0 ignorée(s)")
    end

    it "affiche les PR nécessitant une décision manuelle" do
      progress.summary(
        [
          { repo: "r1", number: 42, action: :skip, reason: "automerge désactivé", needs_decision: true,
            url: "https://github.com/captive-studio/monocle/pull/42", },
        ]
      )

      expect(out.string).to include("https://github.com/captive-studio/monocle/pull/42")
    end
  end
end
