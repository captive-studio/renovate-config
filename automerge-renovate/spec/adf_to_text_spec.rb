# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/adf_to_text"

RSpec.describe AutomergeRenovate::AdfToText do
  describe ".convert" do
    it "laisse une chaîne déjà en texte brut inchangée" do
      expect(described_class.convert("1. Traiter les PR...")).to eq("1. Traiter les PR...")
    end

    it "extrait le texte d'un simple nœud text" do
      node = { "type" => "text", "text" => "Objectif" }

      expect(described_class.convert(node)).to eq("Objectif")
    end

    it "reconstitue un lien Markdown quand le texte porte une marque link" do
      node = {
        "type" => "text",
        "text" => "https://github.com/captive-studio/monocle/pulls",
        "marks" => [ { "type" => "link", "attrs" => { "href" => "https://github.com/captive-studio/monocle/pulls" } } ],
      }

      expect(described_class.convert(node)).to eq(
        "[https://github.com/captive-studio/monocle/pulls](https://github.com/captive-studio/monocle/pulls)"
      )
    end

    it "agrège récursivement le contenu d'un document ADF avec une liste de liens" do
      href = "https://github.com/Captive-Studio/groove-application/pulls"
      doc = {
        "type" => "doc",
        "content" => [
          { "type" => "paragraph", "content" => [ { "type" => "text", "text" => "Repos :" } ] },
          {
            "type" => "bulletList",
            "content" => [
              {
                "type" => "listItem",
                "content" => [
                  {
                    "type" => "paragraph",
                    "content" => [
                      { "type" => "text", "text" => href, "marks" => [ { "type" => "link", "attrs" => { "href" => href } } ] },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      }

      expect(described_class.convert(doc)).to include("[#{href}](#{href})")
    end
  end
end
