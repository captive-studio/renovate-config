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

  describe "#red_checks" do
    it "retourne uniquement les checks non verts" do
      green = { "__typename" => "CheckRun", "status" => "COMPLETED", "conclusion" => "SUCCESS" }
      red = { "__typename" => "CheckRun", "status" => "COMPLETED", "conclusion" => "FAILURE" }

      expect(described_class.new([ green, red ]).red_checks).to eq([ red ])
    end
  end

  describe "#any_red?" do
    it "retourne true quand un check a échoué (conclusion FAILURE)" do
      checks = [{ "__typename" => "CheckRun", "status" => "COMPLETED", "conclusion" => "FAILURE" }]

      expect(described_class.new(checks).any_red?).to be(true)
    end

    it "retourne false quand un CheckRun est en cours (conclusion nil)" do
      checks = [{ "__typename" => "CheckRun", "status" => "IN_PROGRESS", "conclusion" => nil }]

      expect(described_class.new(checks).any_red?).to be(false)
    end

    it "retourne false quand un StatusContext est en attente (state PENDING)" do
      checks = [{ "__typename" => "StatusContext", "context" => "renovate/stability-days", "state" => "PENDING" }]

      expect(described_class.new(checks).any_red?).to be(false)
    end

    it "retourne true si un check est rouge parmi un check en cours" do
      checks = [
        { "__typename" => "CheckRun", "status" => "IN_PROGRESS", "conclusion" => nil },
        { "__typename" => "CheckRun", "status" => "COMPLETED", "conclusion" => "FAILURE" },
      ]

      expect(described_class.new(checks).any_red?).to be(true)
    end

    it "retourne false quand tous les checks sont verts" do
      checks = [{ "__typename" => "CheckRun", "status" => "COMPLETED", "conclusion" => "SUCCESS" }]

      expect(described_class.new(checks).any_red?).to be(false)
    end
  end
end
