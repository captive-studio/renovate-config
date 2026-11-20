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
        progress: kind_of(AutomergeRenovate::ProgressPrinter),
        debug: false,
        wait: false
      )
      expect(command).to have_received(:run).with(ticket_key: "FAC-2000")
    end

    it "active le mode debug avec --debug" do
      described_class.new([], debug: true).automerge

      expect(AutomergeRenovate::AutomergeCommand).to have_received(:new).with(hash_including(debug: true))
    end

    it "active l'attente du rebase et de la CI avec --wait" do
      described_class.new([], wait: true).automerge

      expect(AutomergeRenovate::AutomergeCommand).to have_received(:new).with(hash_including(wait: true))
    end

    it "délègue avec ticket_key à nil quand aucune clé n'est fournie" do
      cli.automerge

      expect(command).to have_received(:run).with(ticket_key: nil)
    end
  end
end
