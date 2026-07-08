# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/automerge_command"
require "automerge_renovate/jira_client"
require "automerge_renovate/gh_cli"
require "automerge_renovate/progress_printer"

RSpec.describe AutomergeRenovate::AutomergeCommand do
  subject(:command) { described_class.new(jira: jira, gh: gh, progress: progress) }

  let(:jira) { instance_double(AutomergeRenovate::JiraClient) }
  let(:gh) { instance_double(AutomergeRenovate::GhCli) }
  let(:progress) { instance_double(AutomergeRenovate::ProgressPrinter, searching: nil, ticket_found: nil,
    repos_found: nil, repo: nil, result: nil, summary: nil) }

  describe "#run" do
    it "utilise le dernier ticket Jira quand aucune clé n'est fournie" do
      allow(jira).to receive(:find_latest_ticket).and_return(
        key: "FAC-1",
        description: "* [https://github.com/captive-studio/monocle/pulls](https://github.com/captive-studio/monocle/pulls)"
      )
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/monocle").and_return([])
      allow(gh).to receive(:merge_settings).with("captive-studio/monocle").and_return({})

      command.run

      expect(progress).to have_received(:ticket_found).with("FAC-1")
    end

    it "utilise le ticket demandé quand une clé est fournie explicitement" do
      allow(jira).to receive(:find_ticket).with("FAC-2000").and_return(
        key: "FAC-2000",
        description: "* [https://github.com/captive-studio/vesta/pulls](https://github.com/captive-studio/vesta/pulls)"
      )
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/vesta").and_return([])
      allow(gh).to receive(:merge_settings).with("captive-studio/vesta").and_return({})

      command.run(ticket_key: "FAC-2000")

      expect(progress).to have_received(:ticket_found).with("FAC-2000")
    end

    it "extrait les repos du ticket et fusionne les PR prêtes en notifiant la progression" do
      pr = { "number" => 7, "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [ { "conclusion" => "SUCCESS" } ], }
      allow(jira).to receive(:find_latest_ticket).and_return(
        key: "FAC-1",
        description: "* [https://github.com/captive-studio/monocle/pulls](https://github.com/captive-studio/monocle/pulls)"
      )
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/monocle").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/monocle").and_return({ "allow_rebase_merge" => true })
      allow(gh).to receive(:merge)

      command.run

      expect(progress).to have_received(:repos_found).with(1)
      expect(progress).to have_received(:repo).with("captive-studio/monocle")
      expect(progress).to have_received(:result).with(
        { repo: "captive-studio/monocle", number: 7, action: :merge, strategy: :rebase }
      )
      expect(progress).to have_received(:summary).with(
        [ { repo: "captive-studio/monocle", number: 7, action: :merge, strategy: :rebase } ]
      )
    end
  end
end
