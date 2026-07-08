# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/jira_client"

RSpec.describe AutomergeRenovate::JiraClient do
  subject(:client) { described_class.new(site: "captive-team.atlassian.net", email: "a@b.fr", token: "tok", http: http) }

  let(:http) { instance_double(AutomergeRenovate::JiraHttp) }

  describe "#find_latest_ticket" do
    it "retourne la clé et la description du premier ticket renvoyé par la recherche JQL" do
      allow(http).to receive(:post)
        .with("/rest/api/3/search/jql", hash_including(:jql, :maxResults, :fields))
        .and_return(
          {
            "issues" => [
              { "key" => "FAC-2514", "fields" => { "description" => "1. Traiter les PR..." } },
            ],
          }
        )

      expect(client.find_latest_ticket).to eq(key: "FAC-2514", description: "1. Traiter les PR...")
    end

    it "interroge le nouvel endpoint search/jql (POST) du projet FAC trié par date de création décroissante" do
      allow(http).to receive(:post)
        .with(
          "/rest/api/3/search/jql",
          jql: 'project = FAC AND summary ~ "Maintenance Renovate" ORDER BY created DESC',
          maxResults: 1,
          fields: %w[summary description]
        )
        .and_return({ "issues" => [ { "key" => "FAC-1", "fields" => { "description" => "peu importe" } } ] })

      expect { client.find_latest_ticket }.not_to raise_error
    end
  end

  describe "#find_ticket" do
    it "récupère un ticket précis par sa clé, sans passer par la recherche JQL" do
      allow(http).to receive(:get)
        .with("/rest/api/3/issue/FAC-2000", {})
        .and_return({ "key" => "FAC-2000", "fields" => { "description" => "description forcée" } })

      expect(client.find_ticket("FAC-2000")).to eq(key: "FAC-2000", description: "description forcée")
    end

    it "convertit une description au format ADF en texte exploitable" do
      href = "https://github.com/captive-studio/monocle/pulls"
      adf_description = {
        "type" => "doc",
        "content" => [
          {
            "type" => "text",
            "text" => href,
            "marks" => [ { "type" => "link", "attrs" => { "href" => href } } ],
          },
        ],
      }
      allow(http).to receive(:get)
        .with("/rest/api/3/issue/FAC-3000", {})
        .and_return({ "key" => "FAC-3000", "fields" => { "description" => adf_description } })

      expect(client.find_ticket("FAC-3000")).to eq(key: "FAC-3000", description: "[#{href}](#{href})")
    end
  end
end
