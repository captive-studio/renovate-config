# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/branch_gap"

RSpec.describe AutomergeRenovate::BranchGap do
  describe "#call" do
    it "enrichit la PR du nombre de commits de retard de sa branche sur sa base" do
      gh = instance_double(AutomergeRenovate::GhCli)
      allow(gh).to receive(:behind_by)
        .with("captive-studio/cae-application", "main", "renovate/openai-7.x")
        .and_return(4)
      pr = { "number" => 1103, "baseRefName" => "main", "headRefName" => "renovate/openai-7.x" }

      enriched = described_class.new(gh: gh).call("captive-studio/cae-application", pr)

      expect(enriched).to eq(pr.merge("behindBy" => 4))
    end

    it "considère la PR à jour quand la comparaison échoue (branche supprimée, base inconnue)" do
      gh = instance_double(AutomergeRenovate::GhCli)
      allow(gh).to receive(:behind_by).and_raise(RuntimeError, "gh api ... failed: 404")
      pr = { "number" => 1104, "baseRefName" => "main", "headRefName" => "renovate/disparue" }

      enriched = described_class.new(gh: gh).call("captive-studio/cae-application", pr)

      expect(enriched).to eq(pr.merge("behindBy" => 0))
    end
  end
end
