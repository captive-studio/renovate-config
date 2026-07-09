# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/failed_checks_rerunner"
require "automerge_renovate/gh_cli"

RSpec.describe AutomergeRenovate::FailedChecksRerunner do
  subject(:rerunner) { described_class.new(gh: gh) }

  let(:gh) { instance_double(AutomergeRenovate::GhCli) }

  describe "#call" do
    it "laisse la décision inchangée quand la PR ne nécessite pas d'investigation" do
      pr = { "statusCheckRollup" => [] }
      decision = { action: :merge, strategy: :rebase }

      expect(rerunner.call("captive-studio/groove-application", pr, decision)).to eq(decision)
    end

    it "redéclenche le job en échec et signale rerun_triggered: true" do
      pr = {
        "statusCheckRollup" => [
          {
            "__typename" => "CheckRun", "conclusion" => "FAILURE",
            "detailsUrl" => "https://github.com/captive-studio/groove-application/actions/runs/28921381928/job/1",
          },
        ],
      }
      decision = { action: :skip, reason: "checks non verts", needs_investigation: true }
      allow(gh).to receive(:rerun_failed_jobs)

      result = rerunner.call("captive-studio/groove-application", pr, decision)

      expect(gh).to have_received(:rerun_failed_jobs).with("captive-studio/groove-application", "28921381928")
      expect(result).to eq(decision.merge(rerun_triggered: true))
    end

    it "signale rerun_triggered: false quand aucun check rouge n'est un run GitHub Actions rejouable" do
      pr = {
        "statusCheckRollup" => [
          { "__typename" => "StatusContext", "context" => "renovate/stability-days", "state" => "FAILURE" },
        ],
      }
      decision = { action: :skip, reason: "checks non verts", needs_investigation: true }
      allow(gh).to receive(:rerun_failed_jobs)

      result = rerunner.call("captive-studio/groove-application", pr, decision)

      expect(gh).not_to have_received(:rerun_failed_jobs)
      expect(result).to eq(decision.merge(rerun_triggered: false))
    end

    it "signale rerun_triggered: false quand gh run rerun échoue" do
      pr = {
        "statusCheckRollup" => [
          {
            "__typename" => "CheckRun", "conclusion" => "FAILURE",
            "detailsUrl" => "https://github.com/captive-studio/groove-application/actions/runs/28921381928/job/1",
          },
        ],
      }
      decision = { action: :skip, reason: "checks non verts", needs_investigation: true }
      allow(gh).to receive(:rerun_failed_jobs).and_raise(RuntimeError, "run trop ancien")

      result = rerunner.call("captive-studio/groove-application", pr, decision)

      expect(result).to eq(decision.merge(rerun_triggered: false))
    end
  end
end
