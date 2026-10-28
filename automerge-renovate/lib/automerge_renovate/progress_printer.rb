# frozen_string_literal: true

require "pastel"
require_relative "report"
require_relative "flagged_pr_list"
require_relative "rebase_waiter"

module AutomergeRenovate
  # Affiche la progression du traitement en direct (recherche du ticket, repos, PR).
  class ProgressPrinter
    SPINNER_FRAMES = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze
    SPINNER_TICK_SECONDS = 0.25
    # Revient en début de ligne et l'efface, pour redessiner la ligne d'attente sur place.
    CLEAR_LINE = "\r\e[K"

    def initialize(pastel: Pastel.new, out: $stdout, sleeper: ->(seconds) { sleep(seconds) },
                   clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @pastel = pastel
      @out = out
      @sleeper = sleeper
      @clock = clock
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

    def waiting_rebase(number)
      @waiting = number
      @waiting_since = @clock.call
      @frame = 0
      draw_waiting
    end

    # Patiente en animant la ligne d'attente : sert de sleeper au RebaseWaiter.
    def wait(seconds)
      (seconds / SPINNER_TICK_SECONDS).round.times do
        @sleeper.call(SPINNER_TICK_SECONDS)
        draw_waiting
      end
    end

    def result(result)
      clear_waiting
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

    def draw_waiting
      minutes, seconds = (@clock.call - @waiting_since).to_i.divmod(RebaseWaiter::SECONDS_PER_MINUTE)
      frame = SPINNER_FRAMES[@frame % SPINNER_FRAMES.size]
      @frame += 1
      elapsed = format("%<minutes>d min %<seconds>02d s", minutes: minutes, seconds: seconds)
      message = "  #{frame} ##{@waiting} : attente du rebase par Renovate et de la CI " \
                "(#{elapsed}, #{RebaseWaiter::TIMEOUT_MINUTES} min max)"
      @out.print CLEAR_LINE + @pastel.dim(message)
    end

    def clear_waiting
      return unless @waiting

      @out.print CLEAR_LINE
      @waiting = nil
    end

    def print_flagged(results, flag, header)
      list = FlaggedPrList.new(results, flag: flag, header: header, pastel: @pastel).to_s
      return if list.empty?

      @out.puts
      @out.puts list
    end
  end
end
