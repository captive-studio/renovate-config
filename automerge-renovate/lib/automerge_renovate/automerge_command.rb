# frozen_string_literal: true

require_relative "repo_url_extractor"
require_relative "runner"

module AutomergeRenovate
  # Orchestre un run complet : ticket Jira -> repos -> fusion des PR -> rapport de progression.
  class AutomergeCommand
    def initialize(jira:, gh:, progress:)
      @jira = jira
      @gh = gh
      @progress = progress
    end

    def run(ticket_key: nil)
      @progress.searching
      ticket = ticket_key ? @jira.find_ticket(ticket_key) : @jira.find_latest_ticket
      @progress.ticket_found(ticket[:key])

      repos = RepoUrlExtractor.new(ticket[:description]).repos
      @progress.repos_found(repos.size)

      results = Runner.new(gh: @gh).run(
        repos,
        on_repo: ->(repo) { @progress.repo(repo) },
        on_result: ->(result) { @progress.result(result) }
      )

      @progress.summary(results)
    end
  end
end
