# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/merge_strategy_picker"

RSpec.describe AutomergeRenovate::MergeStrategyPicker do
  describe "#pick" do
    it "choisit rebase quand le repo l'autorise" do
      settings = { "allow_rebase_merge" => true, "allow_squash_merge" => true, "allow_merge_commit" => true }

      expect(described_class.new(settings).pick).to eq(:rebase)
    end

    it "choisit squash quand rebase n'est pas autorisé" do
      settings = { "allow_rebase_merge" => false, "allow_squash_merge" => true, "allow_merge_commit" => true }

      expect(described_class.new(settings).pick).to eq(:squash)
    end

    it "choisit merge quand ni rebase ni squash ne sont autorisés" do
      settings = { "allow_rebase_merge" => false, "allow_squash_merge" => false, "allow_merge_commit" => true }

      expect(described_class.new(settings).pick).to eq(:merge)
    end

    it "retourne nil quand aucune stratégie n'est autorisée" do
      settings = { "allow_rebase_merge" => false, "allow_squash_merge" => false, "allow_merge_commit" => false }

      expect(described_class.new(settings).pick).to be_nil
    end
  end
end
