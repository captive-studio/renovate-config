# frozen_string_literal: true

require_relative "repo_url_extractor"
require_relative "runner"

module AutomergeRenovate
  # Orchestre un run complet : ticket Jira -> repos -> fusion des PR -> rapport de progression.
  class AutomergeCommand
    def initialize(jira:, gh:, progress:, debug: false, wait: true)
      @debug = debug
      @wait = wait
      @jira = jira
      @gh = gh
      @progress = progress
    end

    # repos: liste fixe qui court-circuite Jira (ex. CI sans token Jira).
    def run(ticket_key: nil, repos: nil)
      repos ||= repos_from_jira(ticket_key)
      @progress.repos_found(repos.size)

      rebase_waiter = RebaseWaiter.new(gh: @gh, sleeper: ->(seconds) { @progress.wait(seconds) })
      results = Runner.new(gh: @gh, rebase_waiter: rebase_waiter, wait: @wait).run(
        repos,
        on_repo: ->(repo) { @progress.repo(repo) },
        on_result: ->(result) { @progress.result(result) },
        on_wait: ->(number) { @progress.waiting_rebase(number) },
        on_decision: ->(pr, decision) { @progress.decision(pr, decision) if @debug }
      )

      @progress.summary(results)
    end

    private

    def repos_from_jira(ticket_key)
      @progress.searching
      ticket = ticket_key ? @jira.find_ticket(ticket_key) : @jira.find_latest_ticket
      @progress.ticket_found(ticket[:key])
      RepoUrlExtractor.new(ticket[:description]).repos
    end
  end
end
