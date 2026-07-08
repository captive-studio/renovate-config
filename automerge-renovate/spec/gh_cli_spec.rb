# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/gh_cli"

RSpec.describe AutomergeRenovate::GhCli do
  subject(:gh) { described_class.new }

  describe "#open_renovate_prs" do
    it "liste les PR ouvertes de l'auteur app/renovate sur le repo" do
      payload = [
        { "number" => 414, "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
          "statusCheckRollup" => [], },
      ].to_json
      allow(gh).to receive(:run)
        .with("pr", "list", "--repo", "captive-studio/groove-application", "--author", "app/renovate",
              "--state", "open", "--json", "number,body,mergeStateStatus,statusCheckRollup")
        .and_return(payload)

      prs = gh.open_renovate_prs("captive-studio/groove-application")

      expect(prs).to eq(
        [
          { "number" => 414, "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
            "statusCheckRollup" => [], },
        ]
      )
    end
  end

  describe "#merge_settings" do
    it "retourne les stratégies de merge autorisées par le repo" do
      payload = { "allow_rebase_merge" => true, "allow_squash_merge" => false,
                  "allow_merge_commit" => true, }.to_json
      allow(gh).to receive(:run)
        .with("api", "repos/captive-studio/groove-application")
        .and_return(payload)

      settings = gh.merge_settings("captive-studio/groove-application")

      expect(settings).to eq(
        "allow_rebase_merge" => true, "allow_squash_merge" => false, "allow_merge_commit" => true
      )
    end
  end

  describe "#merge" do
    it "fusionne la PR avec la stratégie demandée" do
      allow(gh).to receive(:run)
        .with("pr", "merge", "414", "--repo", "captive-studio/groove-application", "--rebase")
        .and_return("")

      expect { gh.merge("captive-studio/groove-application", 414, :rebase) }.not_to raise_error
    end
  end

  describe "#update_body" do
    it "édite le corps de la PR" do
      allow(gh).to receive(:run)
        .with("pr", "edit", "414", "--repo", "captive-studio/groove-application", "--body", "nouveau corps")
        .and_return("")

      expect { gh.update_body("captive-studio/groove-application", 414, "nouveau corps") }.not_to raise_error
    end
  end

  describe "#run" do
    it "exécute gh via Open3 et retourne sa sortie standard en cas de succès" do
      status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3).with("gh", "pr", "list").and_return([ "out\n", "", status ])

      expect(gh.run("pr", "list")).to eq("out\n")
    end

    it "lève une erreur avec la sortie d'erreur quand gh échoue" do
      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture3).with("gh", "pr", "list").and_return([ "", "boom", status ])

      expect { gh.run("pr", "list") }.to raise_error("gh pr list failed: boom")
    end
  end
end
