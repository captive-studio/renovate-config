# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/release_age_gate"

RSpec.describe AutomergeRenovate::ReleaseAgeGate do
  describe "#pending?" do
    it "est en attente quand Renovate n'a pas encore validé l'ancienneté de la version" do
      checks = [ { "context" => "renovate/stability-days", "state" => "PENDING" } ]

      expect(described_class.new(checks).pending?).to be(true)
    end

    it "n'est pas en attente une fois l'ancienneté validée" do
      checks = [ { "context" => "renovate/stability-days", "state" => "SUCCESS" } ]

      expect(described_class.new(checks).pending?).to be(false)
    end

    it "n'est pas en attente sans check d'ancienneté" do
      checks = [ { "name" => "ci / test", "status" => "IN_PROGRESS" } ]

      expect(described_class.new(checks).pending?).to be(false)
    end
  end

  describe ".check?" do
    it "reconnaît le check d'ancienneté de Renovate" do
      expect(described_class.check?({ "context" => "renovate/stability-days" })).to be(true)
      expect(described_class.check?({ "name" => "ci / test" })).to be(false)
    end
  end
end
