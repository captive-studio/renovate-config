# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/flagged_pr_list"

RSpec.describe AutomergeRenovate::FlaggedPrList do
  let(:pastel) { Pastel.new(enabled: false) }

  describe "#to_s" do
    it "retourne une chaîne vide quand aucune PR ne porte le flag" do
      results = [ { repo: "r1", number: 1, action: :merge, strategy: :rebase } ]

      list = described_class.new(results, flag: :needs_decision, header: "peu importe", pastel: pastel)

      expect(list.to_s).to eq("")
    end

    it "liste les PR portant le flag donné, avec leur lien, sous l'en-tête donné" do
      results = [
        { repo: "r1", number: 1, action: :merge, strategy: :rebase },
        { repo: "r1", number: 42, action: :skip, reason: "automerge désactivé", needs_decision: true,
          url: "https://github.com/captive-studio/monocle/pull/42", },
      ]

      list = described_class.new(results, flag: :needs_decision, header: "Décisions à prendre", pastel: pastel)

      expect(list.to_s).to include("Décisions à prendre")
      expect(list.to_s).to include("https://github.com/captive-studio/monocle/pull/42")
    end

    it "mentionne le rerun déclenché quand la PR le porte" do
      results = [
        { repo: "r1", number: 7, action: :skip, reason: "checks non verts", needs_investigation: true,
          rerun_triggered: true, url: "https://github.com/captive-studio/monocle/pull/7", },
      ]

      list = described_class.new(results, flag: :needs_investigation, header: "peu importe", pastel: pastel)

      expect(list.to_s).to include("https://github.com/captive-studio/monocle/pull/7 (rerun déclenché)")
    end
  end
end
