# frozen_string_literal: true

require "pastel"
require_relative "action_tally"

module AutomergeRenovate
  # Formate les résultats du Runner en rapport terminal coloré, groupé par repo.
  class Report
    def self.pr_line(pr, pastel:)
      case pr[:action]
      when :merge
        pastel.green("  ✓ #%<number>d fusionnée (%<strategy>s)" % pr)
      when :rebase_requested
        pastel.yellow("  → #%<number>d rebase demandé" % pr)
      when :skip
        pastel.red("  ✗ #%<number>d ignorée : %<reason>s" % pr)
      end
    end

    def initialize(results, pastel: Pastel.new)
      @results = results
      @pastel = pastel
    end

    def to_s
      [ *lines, "", totals ].join("\n")
    end

    def summary
      totals
    end

    private

    def lines
      by_repo = @results.group_by { |result| result[:repo] }
      by_repo.flat_map { |repo, prs| repo_lines(repo, prs) }
    end

    def totals
      ActionTally.new(@results).to_s
    end

    def repo_lines(repo, prs)
      [ @pastel.bold(repo), *prs.map { |pr| self.class.pr_line(pr, pastel: @pastel) } ]
    end
  end
end
