# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/github_actions_run_ids"

RSpec.describe AutomergeRenovate::GithubActionsRunIds do
  describe ".from" do
    it "extrait les run-id distincts des checks dont le detailsUrl pointe vers un run Actions" do
      checks = [
        { "detailsUrl" => "https://github.com/captive-studio/groove-application/actions/runs/123/job/1" },
        { "detailsUrl" => "https://github.com/captive-studio/groove-application/actions/runs/123/job/2" },
      ]

      expect(described_class.from(checks)).to eq([ "123" ])
    end
  end
end
