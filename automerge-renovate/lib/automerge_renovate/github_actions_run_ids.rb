# frozen_string_literal: true

module AutomergeRenovate
  # Extrait les identifiants de run GitHub Actions distincts depuis une liste de checks.
  module GithubActionsRunIds
    PATTERN = %r{/actions/runs/(\d+)/}

    def self.from(checks)
      checks.filter_map { |check| check["detailsUrl"]&.match(PATTERN)&.captures&.first }.uniq
    end
  end
end
