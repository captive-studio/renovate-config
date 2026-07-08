# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/pr_decision"

RSpec.describe AutomergeRenovate::PrDecision do
  describe "#call" do
    it "ignore la PR quand l'automerge est désactivé et que les checks ne sont pas (tous) verts" do
      pr = { "body" => "🚦 **Automerge**: Disabled by config.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [ { "conclusion" => "FAILURE" } ], }
      merge_settings = { "allow_rebase_merge" => true }

      decision = described_class.new(pr, merge_settings).call

      expect(decision).to eq(action: :skip, reason: "automerge désactivé")
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

    it "ignore la PR quand un check n'est pas vert" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [ { "conclusion" => "FAILURE" } ], }
      merge_settings = { "allow_rebase_merge" => true }

      decision = described_class.new(pr, merge_settings).call

      expect(decision).to eq(action: :skip, reason: "checks non verts")
    end

    it "ignore la PR en cas de conflit (mergeStateStatus autre que CLEAN/BEHIND)" do
      pr = { "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CONFLICTING",
             "statusCheckRollup" => [], }
      merge_settings = { "allow_rebase_merge" => true }

      decision = described_class.new(pr, merge_settings).call

      expect(decision).to eq(action: :skip, reason: "mergeStateStatus: CONFLICTING")
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
