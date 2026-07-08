# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/checks_evaluator"

RSpec.describe AutomergeRenovate::ChecksEvaluator do
  describe "#all_green?" do
    it "retourne true quand l'unique check est un CheckRun terminé en succès" do
      checks = [
        { "__typename" => "CheckRun", "status" => "COMPLETED", "conclusion" => "SUCCESS" },
      ]

      expect(described_class.new(checks).all_green?).to be(true)
    end

    it "considère un CheckRun ignoré (SKIPPED) comme vert" do
      checks = [
        { "__typename" => "CheckRun", "status" => "COMPLETED", "conclusion" => "SKIPPED" },
      ]

      expect(described_class.new(checks).all_green?).to be(true)
    end

    it "considère un CheckRun neutre (NEUTRAL) comme vert" do
      checks = [
        { "__typename" => "CheckRun", "status" => "COMPLETED", "conclusion" => "NEUTRAL" },
      ]

      expect(described_class.new(checks).all_green?).to be(true)
    end

    it "retourne false quand un CheckRun a échoué" do
      checks = [
        { "__typename" => "CheckRun", "status" => "COMPLETED", "conclusion" => "FAILURE" },
      ]

      expect(described_class.new(checks).all_green?).to be(false)
    end

    it "retourne true quand l'unique check est un StatusContext réussi (ex: renovate/stability-days)" do
      checks = [
        { "__typename" => "StatusContext", "context" => "renovate/stability-days", "state" => "SUCCESS" },
      ]

      expect(described_class.new(checks).all_green?).to be(true)
    end

    it "retourne false quand un CheckRun est encore en cours (pas de conclusion)" do
      checks = [
        { "__typename" => "CheckRun", "status" => "IN_PROGRESS", "conclusion" => nil },
      ]

      expect(described_class.new(checks).all_green?).to be(false)
    end

    it "retourne false si un seul check échoue parmi plusieurs verts" do
      checks = [
        { "__typename" => "CheckRun", "status" => "COMPLETED", "conclusion" => "SUCCESS" },
        { "__typename" => "CheckRun", "status" => "COMPLETED", "conclusion" => "FAILURE" },
      ]

      expect(described_class.new(checks).all_green?).to be(false)
    end
  end
end
