# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/repo_url_extractor"

RSpec.describe AutomergeRenovate::RepoUrlExtractor do
  describe "#repos" do
    it "extrait un repo depuis un lien Markdown vers ses pulls" do
      description = "* [https://github.com/Captive-Studio/groove-application/pulls](https://github.com/Captive-Studio/groove-application/pulls)"

      expect(described_class.new(description).repos).to eq([ "Captive-Studio/groove-application" ])
    end

    it "extrait un repo depuis un lien Markdown sans /pulls, juste la racine avec un slash final" do
      description = "* [https://github.com/Captive-Studio/captive-platform/](https://github.com/Captive-Studio/captive-platform/)"

      expect(described_class.new(description).repos).to eq([ "Captive-Studio/captive-platform" ])
    end

    it "extrait plusieurs repos de plusieurs orgs, sans doublon, dans l'ordre du ticket" do
      description = <<~MARKDOWN
        1. Traiter les PR Renovate ouvertes de chacun de ces repos :

        * [https://github.com/Captive-Studio/cae-application/pulls](https://github.com/Captive-Studio/cae-application/pulls)
        * [https://github.com/Captive-Studio/groove-application/pulls](https://github.com/Captive-Studio/groove-application/pulls)
        * [https://github.com/Guitguitou/as-monaco-beachvolley/pulls](https://github.com/Guitguitou/as-monaco-beachvolley/pulls)
        * [https://github.com/Captive-Studio/captive-platform/](https://github.com/Captive-Studio/captive-platform/)
        * [https://github.com/captive-studio/captive-dashboard](https://github.com/captive-studio/captive-dashboard)
      MARKDOWN

      expect(described_class.new(description).repos).to eq(
        [
          "Captive-Studio/cae-application",
          "Captive-Studio/groove-application",
          "Guitguitou/as-monaco-beachvolley",
          "Captive-Studio/captive-platform",
          "captive-studio/captive-dashboard",
        ]
      )
    end

    it "ignore les liens Markdown descriptifs (texte ≠ URL), comme dans une section Ressources" do
      description = <<~MARKDOWN
        * [https://github.com/Captive-Studio/groove-application/pulls](https://github.com/Captive-Studio/groove-application/pulls)

        ### Ressources

        * [Le repo Renovate de Captive](https://github.com/Captive-Studio/renovate-config)
      MARKDOWN

      expect(described_class.new(description).repos).to eq([ "Captive-Studio/groove-application" ])
    end
  end
end
