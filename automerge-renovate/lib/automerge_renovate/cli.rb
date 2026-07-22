# frozen_string_literal: true

require "thor"
require_relative "jira_client"
require_relative "gh_cli"
require_relative "progress_printer"
require_relative "automerge_command"

module AutomergeRenovate
  # Commande Thor : câble Jira, GitHub et le rapport pour la routine de maintenance Renovate.
  class Cli < Thor
    def self.exit_on_failure? = true

    desc "automerge [TICKET_KEY]",
      "Fusionne les PR Renovate prêtes des repos listés dans le ticket Jira de maintenance"
    def automerge(ticket_key = nil)
      command = AutomergeCommand.new(jira: jira, gh: GhCli.new, progress: ProgressPrinter.new)
      command.run(ticket_key: ticket_key)
    end

    private

    def jira
      JiraClient.new(site: ENV.fetch("JIRA_SITE", "captive-team.atlassian.net"),
                      email: ENV.fetch("JIRA_EMAIL"), token: ENV.fetch("JIRA_API_TOKEN"))
    end
  end
end
