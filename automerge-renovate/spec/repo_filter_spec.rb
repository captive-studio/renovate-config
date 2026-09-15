# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/repo_filter"

RSpec.describe AutomergeRenovate::RepoFilter do
  subject(:filter) { described_class.new([ "captive-studio/monocle", "captive-studio/vesta" ]) }

  describe "#apply" do
    it "retourne la liste complète quand aucun repo n'est demandé" do
      expect(filter.apply(nil)).to eq([ "captive-studio/monocle", "captive-studio/vesta" ])
    end

    it "retourne uniquement le repo demandé quand il est listé" do
      expect(filter.apply("captive-studio/vesta")).to eq([ "captive-studio/vesta" ])
    end

    it "retourne le repo tel qu'écrit dans le ticket, indépendamment de la casse demandée" do
      filter = described_class.new([ "Captive-Studio/monocle" ])

      expect(filter.apply("captive-studio/MONOCLE")).to eq([ "Captive-Studio/monocle" ])
    end

    it "lève une erreur explicite quand le repo demandé n'est pas listé" do
      expect { filter.apply("captive-studio/inconnu") }.to raise_error(
        AutomergeRenovate::RepoNotInTicketError,
        'Le repo "captive-studio/inconnu" n\'est pas listé dans ce ticket. ' \
          "Repos disponibles : captive-studio/monocle, captive-studio/vesta"
      )
    end
  end
end
