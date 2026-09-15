# frozen_string_literal: true

require_relative "errors"

module AutomergeRenovate
  # Permet de ne lancer l'automerge que sur un seul repo du ticket, via l'option --repo.
  class RepoFilter
    def initialize(repos)
      @repos = repos
    end

    def apply(repo)
      return @repos unless repo

      match = @repos.find { |candidate| candidate.casecmp?(repo) }
      raise RepoNotInTicketError, message(repo) unless match

      [ match ]
    end

    private

    def message(repo)
      %(Le repo "#{repo}" n'est pas listé dans ce ticket. Repos disponibles : #{@repos.join(', ')})
    end
  end
end
