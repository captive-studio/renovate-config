# frozen_string_literal: true

require "pastel"
require_relative "action_tally"

module AutomergeRenovate
  # Formate les résultats du Runner en rapport terminal coloré, groupé par repo.
  class Report
    def self.pr_line(pr, pastel:)
      ref = pr_ref(pr, pastel)
      case pr[:action]
      when :merge
        pastel.green("  ✓ #{ref} fusionnée (#{pr[:strategy]})")
      when :rebase_requested
        pastel.yellow("  → #{ref} rebase demandé")
      when :skip
        pastel.red("  ✗ #{ref} ignorée : #{pr[:reason]}")
      end
    end

    # Lien cliquable OSC 8 vers la PR, seulement dans un vrai terminal.
    def self.pr_ref(pr, pastel)
      ref = "##{pr[:number]}"
      return ref unless $stdout.tty? && pr[:repo]

      "\e]8;;https://github.com/#{pr[:repo]}/pull/#{pr[:number]}\e\\#{ref}\e]8;;\e\\"
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
