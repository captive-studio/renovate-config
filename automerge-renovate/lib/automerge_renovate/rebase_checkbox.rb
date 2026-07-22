# frozen_string_literal: true

module AutomergeRenovate
  class RebaseCheckbox
    MARKER = "<!-- rebase-check -->"

    def initialize(body)
      @body = body
    end

    def check
      @body.sub("- [ ] #{MARKER}", "- [x] #{MARKER}")
    end
  end
end
