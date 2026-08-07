# frozen_string_literal: true

require_relative "gh_cli"

module AutomergeRenovate
  # Ajoute à une PR son retard réel sur la branche de base : GitHub ne le remonte dans
  # mergeStateStatus (BEHIND) que si la base exige d'être à jour, ce qui n'est pas le cas partout.
  class BranchGap
    def initialize(gh:)
      @gh = gh
    end

    def call(repo, pr)
      pr.merge("behindBy" => behind_by(repo, pr))
    end

    private

    # Une branche supprimée ou une base inconnue fait échouer la comparaison : la PR n'est
    # alors pas rebasable, on la traite comme à jour plutôt que d'interrompre le run.
    def behind_by(repo, pr)
      @gh.behind_by(repo, pr["baseRefName"], pr["headRefName"])
    rescue RuntimeError
      0
    end
  end
end
