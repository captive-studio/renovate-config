# frozen_string_literal: true

require "pastel"
require_relative "report"
require_relative "flagged_pr_list"

module AutomergeRenovate
  # Affiche la progression du traitement en direct (recherche du ticket, repos, PR).
  class ProgressPrinter
    def initialize(pastel: Pastel.new, out: $stdout)
      @pastel = pastel
      @out = out
    end

    def searching
      @out.puts @pastel.dim("→ Recherche du ticket Jira...")
    end

    def ticket_found(key)
      @out.puts @pastel.dim("→ Ticket #{key} trouvé.")
    end

    def repos_found(count)
      @out.puts @pastel.dim("→ #{count} repo(s) à traiter.")
    end

    def repo(name)
      @out.puts @pastel.bold(name)
    end

    def result(result)
      @out.puts Report.pr_line(result, pastel: @pastel)
    end

    def summary(results)
      @out.puts
      @out.puts Report.new(results, pastel: @pastel).summary

      decision_header = "⚠ Décisions à prendre (checks verts, automerge désactivé) :"
      print_flagged(results, :needs_decision, decision_header)
      print_flagged(results, :needs_decision_red, "⚠ Décisions à prendre (checks rouges, automerge désactivé) :")
      print_flagged(results, :needs_investigation, "⚠ PR à investiguer (checks rouges) :")
    end

    private

    def print_flagged(results, flag, header)
      list = FlaggedPrList.new(results, flag: flag, header: header, pastel: @pastel).to_s
      return if list.empty?

      @out.puts
      @out.puts list
    end
  end
end
