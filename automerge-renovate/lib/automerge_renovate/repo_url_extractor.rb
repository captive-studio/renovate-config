# frozen_string_literal: true

module AutomergeRenovate
  # Extrait les repos GitHub listés dans la description d'un ticket Jira de maintenance.
  class RepoUrlExtractor
    REPO_URL_PATTERN = %r{
      \[https://github\.com/([^/\s\]]+/[^/\s\]]+?)(?:/pulls?)?/?\]
      \(https://github\.com/[^)]+\)
    }x

    def initialize(description)
      @description = description
    end

    def repos
      @description.scan(REPO_URL_PATTERN).map(&:first).uniq
    end
  end
end
