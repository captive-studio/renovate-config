# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/runner"
require "automerge_renovate/gh_cli"

RSpec.describe AutomergeRenovate::Runner do
  subject(:runner) { described_class.new(gh: gh) }

  let(:gh) { instance_double(AutomergeRenovate::GhCli) }

  describe "#run" do
    it "fusionne une PR prête et retourne le résultat de l'action" do
      pr = { "number" => 414, "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [ { "conclusion" => "SUCCESS" } ], }
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/groove-application").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/groove-application")
        .and_return({ "allow_rebase_merge" => true })
      allow(gh).to receive(:merge)

      results = runner.run([ "captive-studio/groove-application" ])

      expect(results).to eq(
        [
          { repo: "captive-studio/groove-application", number: 414, url: nil, action: :merge, strategy: :rebase },
        ]
      )
      expect(gh).to have_received(:merge).with("captive-studio/groove-application", 414, :rebase)
    end

    it "coche la case rebase quand la branche n'est pas à jour" do
      pr = { "number" => 1008, "body" => "🚦 **Automerge**: Enabled.\n- [ ] <!-- rebase-check -->coche-moi",
             "mergeStateStatus" => "BEHIND", "statusCheckRollup" => [], }
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/cae-application").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/cae-application").and_return({})
      allow(gh).to receive(:update_body)

      results = runner.run([ "captive-studio/cae-application" ])

      expect(results).to eq(
        [ { repo: "captive-studio/cae-application", number: 1008, url: nil, action: :rebase_requested } ]
      )
      expect(gh).to have_received(:update_body).with(
        "captive-studio/cae-application", 1008,
        "🚦 **Automerge**: Enabled.\n- [x] <!-- rebase-check -->coche-moi"
      )
    end

    it "inclut l'URL de la PR dans le résultat, pour les PR nécessitant une décision" do
      pr = { "number" => 42, "body" => "🚦 **Automerge**: Disabled by config.",
             "mergeStateStatus" => "CLEAN", "statusCheckRollup" => [ { "conclusion" => "SUCCESS" } ],
             "url" => "https://github.com/captive-studio/monocle/pull/42", }
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/monocle").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/monocle").and_return({})

      results = runner.run([ "captive-studio/monocle" ])

      expect(results).to eq(
        [
          { repo: "captive-studio/monocle", number: 42, action: :skip, reason: "automerge désactivé",
            needs_decision: true, url: "https://github.com/captive-studio/monocle/pull/42", },
        ]
      )
    end

    it "n'appelle ni merge ni update_body quand la PR est ignorée" do
      pr = { "number" => 42, "body" => "🚦 **Automerge**: Disabled by config.",
             "mergeStateStatus" => "CLEAN", "statusCheckRollup" => [ { "conclusion" => "FAILURE" } ], }
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/monocle").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/monocle").and_return({})
      allow(gh).to receive(:merge)
      allow(gh).to receive(:update_body)

      results = runner.run([ "captive-studio/monocle" ])

      expect(results).to eq(
        [ { repo: "captive-studio/monocle", number: 42, url: nil, action: :skip, reason: "automerge désactivé" } ]
      )
      expect(gh).not_to have_received(:merge)
      expect(gh).not_to have_received(:update_body)
    end

    it "continue sur les autres PR quand gh échoue sur l'une d'elles" do
      pr = { "number" => 414, "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [ { "conclusion" => "SUCCESS" } ], }
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/groove-application").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/groove-application")
        .and_return({ "allow_rebase_merge" => true })
      allow(gh).to receive(:merge).and_raise(RuntimeError, "GraphQL: Merge already in progress")

      results = runner.run([ "captive-studio/groove-application" ])

      expect(results).to eq(
        [
          { repo: "captive-studio/groove-application", number: 414, url: nil, action: :skip,
            reason: "GraphQL: Merge already in progress", },
        ]
      )
    end

    it "notifie on_repo avant de traiter un repo, et on_result dès qu'une PR est traitée" do
      pr = { "number" => 414, "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [ { "conclusion" => "SUCCESS" } ], }
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/groove-application").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/groove-application")
        .and_return({ "allow_rebase_merge" => true })
      allow(gh).to receive(:merge)
      repos_seen = []
      results_seen = []

      runner.run(
        [ "captive-studio/groove-application" ],
        on_repo: ->(repo) { repos_seen << repo },
        on_result: ->(result) { results_seen << result }
      )

      expect(repos_seen).to eq([ "captive-studio/groove-application" ])
      expect(results_seen).to eq(
        [ { repo: "captive-studio/groove-application", number: 414, url: nil, action: :merge, strategy: :rebase } ]
      )
    end
  end
end
