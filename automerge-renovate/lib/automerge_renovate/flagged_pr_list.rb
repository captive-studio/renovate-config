# frozen_string_literal: true

require "pastel"

module AutomergeRenovate
  # Liste les PR portant un flag donné (needs_decision, needs_investigation...), avec leur lien.
  class FlaggedPrList
    def initialize(results, flag:, header:, pastel: Pastel.new)
      @results = results
      @flag = flag
      @header = header
      @pastel = pastel
    end

    def to_s
      return "" if prs.empty?

      [ @pastel.yellow.bold(@header), *lines ].join("\n")
    end

    private

    def prs
      @results.select { |result| result[@flag] }
    end

    def lines
      prs.map { |pr| "  - #{pr[:url]}#{" (rerun déclenché)" if pr[:rerun_triggered]}" }
    end
  end
end
