# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/rebase_waiter"
require "automerge_renovate/gh_cli"

RSpec.describe AutomergeRenovate::RebaseWaiter do
  subject(:waiter) { described_class.new(gh: gh, sleeper: sleeper) }

  let(:gh) { instance_double(AutomergeRenovate::GhCli) }
  let(:sleeper) { instance_double(Proc, call: nil) }
  let(:pr) { { "number" => 1008, "headRefOid" => "old" } }
  let(:settled) do
    { "number" => 1008, "headRefOid" => "new",
      "statusCheckRollup" => [ { "status" => "COMPLETED", "conclusion" => "SUCCESS" } ], }
  end

  describe "#call" do
    it "retourne la PR relue une fois rebasée et ses checks terminés" do
      allow(gh).to receive(:pr).with("captive-studio/cae-application", 1008).and_return(settled)

      expect(waiter.call("captive-studio/cae-application", pr)).to eq(settled)
      expect(sleeper).not_to have_received(:call)
    end

    it "patiente tant que Renovate n'a pas poussé de nouveau commit" do
      allow(gh).to receive(:pr).and_return(pr, settled)

      expect(waiter.call("captive-studio/cae-application", pr)).to eq(settled)
      expect(sleeper).to have_received(:call).with(15).once
    end

    it "patiente tant que des checks sont en cours" do
      running = settled.merge("statusCheckRollup" => [
                                { "status" => "IN_PROGRESS", "conclusion" => "" },
                                { "state" => "PENDING" },
                              ])
      allow(gh).to receive(:pr).and_return(running, settled)

      expect(waiter.call("captive-studio/cae-application", pr)).to eq(settled)
      expect(sleeper).to have_received(:call).once
    end

    it "patiente tant qu'aucun check n'est encore apparu sur le nouveau commit" do
      allow(gh).to receive(:pr).and_return(settled.merge("statusCheckRollup" => []), settled)

      expect(waiter.call("captive-studio/cae-application", pr)).to eq(settled)
      expect(sleeper).to have_received(:call).once
    end

    it "abandonne au bout de 15 minutes" do
      expect(described_class::POLL_ATTEMPTS * described_class::POLL_INTERVAL_SECONDS).to eq(15 * 60)
    end

    it "abandonne et retourne nil au bout du nombre maximal de tentatives" do
      allow(gh).to receive(:pr).and_return(pr)

      expect(waiter.call("captive-studio/cae-application", pr)).to be_nil
      expect(gh).to have_received(:pr).exactly(described_class::POLL_ATTEMPTS).times
    end
  end
end
