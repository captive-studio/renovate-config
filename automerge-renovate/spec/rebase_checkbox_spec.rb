# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/rebase_checkbox"

RSpec.describe AutomergeRenovate::RebaseCheckbox do
  describe "#check" do
    it "coche la case rebase non cochée du corps de la PR" do
      body = "- [ ] <!-- rebase-check -->If you want to rebase/retry this PR, check this box"

      result = described_class.new(body).check

      expect(result).to eq("- [x] <!-- rebase-check -->If you want to rebase/retry this PR, check this box")
    end

    it "laisse le corps inchangé si la case est déjà cochée" do
      body = "- [x] <!-- rebase-check -->If you want to rebase/retry this PR, check this box"

      result = described_class.new(body).check

      expect(result).to eq(body)
    end
  end
end
