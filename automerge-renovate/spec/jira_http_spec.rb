# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/jira_http"

RSpec.describe AutomergeRenovate::JiraHttp do
  subject(:http) { described_class.new(site: "captive-team.atlassian.net", email: "a@b.fr", token: "tok") }

  describe "#get" do
    it "envoie une requête HTTP authentifiée en Basic Auth et parse la réponse JSON" do
      fake_response = instance_double(Net::HTTPResponse, body: '{"ok":true}')
      fake_http = instance_double(Net::HTTP, request: fake_response)
      allow(Net::HTTP).to receive(:start)
        .with("captive-team.atlassian.net", 443, use_ssl: true)
        .and_yield(fake_http)

      result = http.get("/rest/api/3/issue/FAC-1", { foo: "bar" })

      expect(result).to eq("ok" => true)
      expect(fake_http).to have_received(:request) do |request|
        expect(request).to be_a(Net::HTTP::Get)
        expect(request.uri.to_s).to eq("https://captive-team.atlassian.net/rest/api/3/issue/FAC-1?foo=bar")
        expect(request["authorization"]).to start_with("Basic ")
      end
    end
  end

  describe "#post" do
    it "envoie une requête POST JSON authentifiée en Basic Auth et parse la réponse" do
      fake_response = instance_double(Net::HTTPResponse, body: '{"issues":[]}')
      fake_http = instance_double(Net::HTTP, request: fake_response)
      allow(Net::HTTP).to receive(:start)
        .with("captive-team.atlassian.net", 443, use_ssl: true)
        .and_yield(fake_http)

      result = http.post("/rest/api/3/search/jql", jql: "project = FAC", maxResults: 1)

      expect(result).to eq("issues" => [])
      expect(fake_http).to have_received(:request) do |request|
        expect(request).to be_a(Net::HTTP::Post)
        expect(request.uri.to_s).to eq("https://captive-team.atlassian.net/rest/api/3/search/jql")
        expect(request["authorization"]).to start_with("Basic ")
        expect(request["content-type"]).to eq("application/json")
        expect(JSON.parse(request.body)).to eq("jql" => "project = FAC", "maxResults" => 1)
      end
    end
  end
end
