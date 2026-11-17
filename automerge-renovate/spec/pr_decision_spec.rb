# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/pr_decision"

RSpec.describe AutomergeRenovate::PrDecision do
  describe "#call" do
    it "signale needs_decision_red quand l'automerge est désactivé et que les checks ne sont pas (tous) verts" do
      pr = { "body" => "🚦 **Automerge**: Disabled by config.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [ { "conclusion" => "FAILURE" } ], }
      merge_settings = { "allow_rebase_merge" => true }

      decision = described_class.new(pr, merge_settings).call

      expect(decision).to eq(action: :skip, reason: "automerge désactivé", needs_decision_red: true)
    end

    it "signale needs_decision quand l'automerge est désactivé mais que les checks sont verts" do
      pr = { "body" => "🚦 **Automerge**: Disabled by config.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [ { "conclusion" => "SUCCESS" } ], }
      merge_settings = { "allow_rebase_merge" => true }

      decision = described_class.new(pr, merge_settings).call

      expect(decision).to eq(action: :skip, reason: "automerge désactivé", needs_decision: true)
    end

    it "demande un rebase quand la branche n'est pas à jour (BEHIND)" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "BEHIND",
             "statusCheckRollup" => [], }
      merge_settings = { "allow_rebase_merge" => true }

      decision = described_class.new(pr, merge_settings).call

      expect(decision).to eq(action: :rebase_requested)
    end

    it "ne rebase pas une branche en retard dont l'automerge est désactivé : décision humaine" do
      pr = { "body" => "🚦 **Automerge**: Disabled by config.", "mergeStateStatus" => "UNSTABLE",
             "behindBy" => 4, "statusCheckRollup" => [ { "conclusion" => "FAILURE" } ], }
      merge_settings = { "allow_rebase_merge" => true }

      decision = described_class.new(pr, merge_settings).call

      expect(decision).to eq(action: :skip, reason: "automerge désactivé", needs_decision_red: true)
    end

    it "fusionne directement une PR verte en retard quand GitHub accepte le merge (CLEAN)" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
             "behindBy" => 4, "statusCheckRollup" => [ { "conclusion" => "SUCCESS" } ], }
      merge_settings = { "allow_rebase_merge" => true }

      decision = described_class.new(pr, merge_settings).call

      expect(decision).to eq(action: :merge, strategy: :rebase)
    end

    it "classe à investiguer une PR rouge fusionnable telle quelle, sans la rebaser" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "UNSTABLE",
             "statusCheckRollup" => [ { "conclusion" => "FAILURE" } ], }

      decision = described_class.new(pr, { "allow_rebase_merge" => true }).call

      expect(decision).to eq(action: :skip, reason: "checks non verts", needs_investigation: true)
    end

    it "attend que GitHub calcule l'état de fusion plutôt que d'agir sur UNKNOWN" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "UNKNOWN",
             "statusCheckRollup" => [ { "conclusion" => "SUCCESS" } ], }

      decision = described_class.new(pr, { "allow_rebase_merge" => true }).call

      expect(decision).to eq(action: :skip, reason: "état de fusion pas encore calculé par GitHub")
    end

    it "signale les artefacts Renovate en échec, sans relance possible de la CI" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "UNSTABLE",
             "statusCheckRollup" => [ { "context" => "renovate/artifacts", "state" => "FAILURE" },
                                      { "conclusion" => "FAILURE" }, ], }

      decision = described_class.new(pr, { "allow_rebase_merge" => true }).call

      expect(decision).to eq(action: :skip, reason: "artefacts Renovate en échec",
                             needs_investigation: true, rerunnable: false)
    end

    it "ne rebase pas une PR verte que GitHub bloque pour une autre raison qu'un retard" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "BLOCKED",
             "statusCheckRollup" => [ { "conclusion" => "SUCCESS" } ], }

      decision = described_class.new(pr, { "allow_rebase_merge" => true }).call

      expect(decision).to eq(action: :skip, reason: "fusion bloquée par GitHub (BLOCKED)")
    end

    it "attend la PR sans la signaler à investiguer quand des checks sont en cours" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [ { "status" => "IN_PROGRESS", "conclusion" => nil } ], }

      decision = described_class.new(pr, { "allow_rebase_merge" => true }).call

      expect(decision).to eq(action: :skip, reason: "checks en cours")
    end

    it "indique que la version est trop récente quand Renovate attend son ancienneté" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [ { "context" => "renovate/stability-days", "state" => "PENDING" } ], }

      decision = described_class.new(pr, { "allow_rebase_merge" => true }).call

      expect(decision).to eq(action: :skip, reason: "version trop récente (minimumReleaseAge)")
    end

    it "ignore la PR quand un check n'est pas vert" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [ { "conclusion" => "FAILURE" } ], }
      merge_settings = { "allow_rebase_merge" => true }

      decision = described_class.new(pr, merge_settings).call

      expect(decision).to eq(action: :skip, reason: "checks non verts", needs_investigation: true)
    end

    it "demande un rebase en cas de conflit (DIRTY) : Renovate résout en régénérant la branche" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "DIRTY",
             "statusCheckRollup" => [], }
      merge_settings = { "allow_rebase_merge" => true }

      decision = described_class.new(pr, merge_settings).call

      expect(decision).to eq(action: :rebase_requested)
    end

    it "demande un rebase en cas de conflit (DIRTY) même quand les checks sont rouges" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "DIRTY",
             "statusCheckRollup" => [ { "conclusion" => "FAILURE" } ], }
      merge_settings = { "allow_rebase_merge" => true }

      decision = described_class.new(pr, merge_settings).call

      expect(decision).to eq(action: :rebase_requested)
    end

    it "fusionne la PR quand tout est au vert, avec la stratégie autorisée par le repo" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [ { "conclusion" => "SUCCESS" } ], }
      merge_settings = { "allow_rebase_merge" => true }

      decision = described_class.new(pr, merge_settings).call

      expect(decision).to eq(action: :merge, strategy: :rebase)
    end

    it "ignore la PR quand le repo n'autorise aucune stratégie de merge" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [ { "conclusion" => "SUCCESS" } ], }
      merge_settings = { "allow_rebase_merge" => false, "allow_squash_merge" => false,
                          "allow_merge_commit" => false, }

      decision = described_class.new(pr, merge_settings).call

      expect(decision).to eq(action: :skip, reason: "aucune stratégie de merge autorisée")
    end
  end
end
