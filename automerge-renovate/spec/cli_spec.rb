# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/cli"

RSpec.describe AutomergeRenovate::Cli do
  subject(:cli) { described_class.new }

  let(:command) { instance_double(AutomergeRenovate::AutomergeCommand, run: nil) }

  before(:each) do
    ENV["JIRA_SITE"] = "captive-team.atlassian.net"
    ENV["JIRA_EMAIL"] = "a@b.fr"
    ENV["JIRA_API_TOKEN"] = "tok"
    allow(AutomergeRenovate::AutomergeCommand).to receive(:new).and_return(command)
  end

  describe "#automerge" do
    it "construit la commande et lui délègue l'exécution avec la clé de ticket fournie" do
      cli.automerge("FAC-2000")

      expect(AutomergeRenovate::AutomergeCommand).to have_received(:new).with(
        jira: kind_of(AutomergeRenovate::JiraClient),
        gh: kind_of(AutomergeRenovate::GhCli),
        progress: kind_of(AutomergeRenovate::ProgressPrinter)
      )
      expect(command).to have_received(:run).with(ticket_key: "FAC-2000", repo: nil)
    end

    it "délègue avec ticket_key à nil quand aucune clé n'est fournie" do
      cli.automerge

      expect(command).to have_received(:run).with(ticket_key: nil, repo: nil)
    end

    it "transmet le repo demandé via l'option --repo" do
      cli = described_class.new([], repo: "captive-studio/monocle")

      cli.automerge("FAC-2000")

      expect(command).to have_received(:run).with(ticket_key: "FAC-2000", repo: "captive-studio/monocle")
    end
  end
end
