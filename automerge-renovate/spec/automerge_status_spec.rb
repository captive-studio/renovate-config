# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/automerge_status"

RSpec.describe AutomergeRenovate::AutomergeStatus do
  describe "#enabled?" do
    it "retourne true quand le corps contient le marqueur Renovate d'automerge activé" do
      body = "🚦 **Automerge**: Enabled.\n"

      status = described_class.new(body)

      expect(status.enabled?).to be(true)
    end

    it "retourne false quand le corps indique que l'automerge est désactivé" do
      body = "🚦 **Automerge**: Disabled by config. Please merge this manually once you are satisfied.\n"

      status = described_class.new(body)

      expect(status.enabled?).to be(false)
    end
  end
end
