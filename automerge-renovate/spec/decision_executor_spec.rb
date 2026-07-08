# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/decision_executor"
require "automerge_renovate/gh_cli"

RSpec.describe AutomergeRenovate::DecisionExecutor do
  subject(:executor) { described_class.new(gh: gh) }

  let(:gh) { instance_double(AutomergeRenovate::GhCli) }
  let(:pr) { { "number" => 414, "body" => "🚦 **Automerge**: Enabled." } }

  describe "#call" do
    it "fusionne la PR quand la décision est :merge" do
      allow(gh).to receive(:merge)

      decision = executor.call("captive-studio/groove-application", pr, { action: :merge, strategy: :rebase })

      expect(gh).to have_received(:merge).with("captive-studio/groove-application", 414, :rebase)
      expect(decision).to eq(action: :merge, strategy: :rebase)
    end

    it "coche la case rebase quand la décision est :rebase_requested" do
      body_pr = pr.merge("body" => "🚦 **Automerge**: Enabled.\n- [ ] <!-- rebase-check -->coche-moi")
      allow(gh).to receive(:update_body)

      decision = executor.call("captive-studio/cae-application", body_pr, { action: :rebase_requested })

      expect(gh).to have_received(:update_body).with(
        "captive-studio/cae-application", 414,
        "🚦 **Automerge**: Enabled.\n- [x] <!-- rebase-check -->coche-moi"
      )
      expect(decision).to eq(action: :rebase_requested)
    end

    it "convertit un échec gh en skip plutôt que de laisser l'exception se propager" do
      allow(gh).to receive(:merge).and_raise(RuntimeError, "GraphQL: Merge already in progress")

      decision = executor.call("captive-studio/groove-application", pr, { action: :merge, strategy: :rebase })

      expect(decision).to eq(action: :skip, reason: "GraphQL: Merge already in progress")
    end
  end
end
