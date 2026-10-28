# frozen_string_literal: true

require "spec_helper"
require "automerge_renovate/runner"
require "automerge_renovate/gh_cli"
require "automerge_renovate/rebase_waiter"

RSpec.describe AutomergeRenovate::Runner do
  subject(:runner) { described_class.new(gh: gh, rebase_waiter: rebase_waiter) }

  let(:gh) { instance_double(AutomergeRenovate::GhCli) }
  let(:rebase_waiter) { instance_double(AutomergeRenovate::RebaseWaiter, call: nil) }

  before(:each) do
    allow(gh).to receive(:behind_by).and_return(0)
    allow(gh).to receive(:merged?).and_return(true)
  end

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

    it "coche la case rebase quand la branche est en retard sans que GitHub la marque BEHIND" do
      pr = { "number" => 1103, "body" => "🚦 **Automerge**: Enabled.\n- [ ] <!-- rebase-check -->coche-moi",
             "mergeStateStatus" => "UNSTABLE", "baseRefName" => "main",
             "headRefName" => "renovate/openai-7.x",
             "statusCheckRollup" => [ { "conclusion" => "FAILURE" } ], }
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/cae-application").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/cae-application").and_return({})
      allow(gh).to receive(:behind_by)
        .with("captive-studio/cae-application", "main", "renovate/openai-7.x").and_return(4)
      allow(gh).to receive(:update_body)

      results = runner.run([ "captive-studio/cae-application" ])

      expect(results).to eq(
        [ { repo: "captive-studio/cae-application", number: 1103, url: nil, action: :rebase_requested } ]
      )
      expect(gh).to have_received(:update_body).with(
        "captive-studio/cae-application", 1103,
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

    it "redéclenche les checks rouges d'une PR à investiguer et le signale dans le résultat" do
      pr = { "number" => 7, "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [
               { "conclusion" => "FAILURE",
                 "detailsUrl" => "https://github.com/captive-studio/monocle/actions/runs/123/job/1", },
             ], }
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/monocle").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/monocle").and_return({})
      allow(gh).to receive(:rerun_failed_jobs)

      results = runner.run([ "captive-studio/monocle" ])

      expect(gh).to have_received(:rerun_failed_jobs).with("captive-studio/monocle", "123")
      expect(results).to eq(
        [
          { repo: "captive-studio/monocle", number: 7, url: nil, action: :skip, reason: "checks non verts",
            needs_investigation: true, rerun_triggered: true, },
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
        [
          { repo: "captive-studio/monocle", number: 42, url: nil, action: :skip, reason: "automerge désactivé",
            needs_decision_red: true, rerun_triggered: false, },
        ]
      )
      expect(gh).not_to have_received(:merge)
      expect(gh).not_to have_received(:update_body)
    end

    it "redéclenche les checks rouges d'une PR désactivée et le signale dans le résultat" do
      pr = { "number" => 822, "body" => "🚦 **Automerge**: Disabled by config.", "mergeStateStatus" => "CLEAN",
             "statusCheckRollup" => [
               { "conclusion" => "FAILURE",
                 "detailsUrl" => "https://github.com/captive-studio/monocle/actions/runs/456/job/1", },
             ], }
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/monocle").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/monocle").and_return({})
      allow(gh).to receive(:rerun_failed_jobs)

      results = runner.run([ "captive-studio/monocle" ])

      expect(gh).to have_received(:rerun_failed_jobs).with("captive-studio/monocle", "456")
      expect(results).to eq(
        [
          { repo: "captive-studio/monocle", number: 822, url: nil, action: :skip, reason: "automerge désactivé",
            needs_decision_red: true, rerun_triggered: true, },
        ]
      )
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

    it "attend le rebase d'une PR en retard puis la fusionne, pour tout merger en un seul run" do
      body = "🚦 **Automerge**: Enabled.\n- [ ] <!-- rebase-check -->coche-moi"
      first = { "number" => 1, "body" => body, "mergeStateStatus" => "CLEAN",
                "statusCheckRollup" => [ { "conclusion" => "SUCCESS" } ], }
      second = { "number" => 2, "body" => body, "mergeStateStatus" => "BEHIND",
                 "statusCheckRollup" => [ { "conclusion" => "SUCCESS" } ], }
      rebased = second.merge("mergeStateStatus" => "CLEAN")
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/monocle").and_return([ first, second ])
      allow(gh).to receive(:merge_settings).with("captive-studio/monocle")
        .and_return({ "allow_rebase_merge" => true })
      allow(gh).to receive(:merge)
      allow(gh).to receive(:update_body)
      allow(rebase_waiter).to receive(:call).with("captive-studio/monocle", second).and_return(rebased)

      waited = []
      results = runner.run([ "captive-studio/monocle" ], on_wait: ->(number) { waited << number })

      expect(waited).to eq([ 2 ])
      expect(gh).to have_received(:update_body).with("captive-studio/monocle", 2, anything)
      expect(gh).to have_received(:merge).with("captive-studio/monocle", 2, :rebase)
      expect(results).to eq(
        [
          { repo: "captive-studio/monocle", number: 1, url: nil, action: :merge, strategy: :rebase },
          { repo: "captive-studio/monocle", number: 2, url: nil, action: :merge, strategy: :rebase },
        ]
      )
    end

    it "laisse la PR en rebase demandé quand le rebase n'aboutit pas à temps" do
      pr = { "number" => 3, "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "BEHIND",
             "statusCheckRollup" => [], }
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/monocle").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/monocle").and_return({})
      allow(gh).to receive(:update_body)

      results = runner.run([ "captive-studio/monocle" ])

      expect(rebase_waiter).to have_received(:call).once
      expect(results).to eq([ { repo: "captive-studio/monocle", number: 3, url: nil, action: :rebase_requested } ])
    end

    it "n'attend pas le rebase d'une PR dont l'automerge est désactivé" do
      pr = { "number" => 4, "body" => "🚦 **Automerge**: Disabled by config.", "mergeStateStatus" => "BEHIND",
             "statusCheckRollup" => [], }
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/monocle").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/monocle").and_return({})
      allow(gh).to receive(:update_body)

      runner.run([ "captive-studio/monocle" ])

      expect(rebase_waiter).not_to have_received(:call)
    end

    it "abandonne après un nombre maximal de rebases successifs" do
      pr = { "number" => 5, "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "BEHIND",
             "statusCheckRollup" => [], }
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/monocle").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/monocle").and_return({})
      allow(gh).to receive(:update_body)
      allow(rebase_waiter).to receive(:call).and_return(pr)

      results = runner.run([ "captive-studio/monocle" ])

      expect(rebase_waiter).to have_received(:call).exactly(described_class::MAX_REBASES).times
      expect(results.last[:action]).to eq(:rebase_requested)
    end

    it "n'attend pas le rebase d'une PR qui attend l'ancienneté minimale de sa version" do
      pr = { "number" => 1368, "body" => "🚦 **Automerge**: Enabled.", "mergeStateStatus" => "DIRTY",
             "statusCheckRollup" => [ { "context" => "renovate/stability-days", "state" => "PENDING" } ], }
      allow(gh).to receive(:open_renovate_prs).with("captive-studio/cae-application").and_return([ pr ])
      allow(gh).to receive(:merge_settings).with("captive-studio/cae-application").and_return({})
      allow(gh).to receive(:update_body)

      results = runner.run([ "captive-studio/cae-application" ])

      expect(rebase_waiter).not_to have_received(:call)
      expect(results).to eq(
        [ { repo: "captive-studio/cae-application", number: 1368, url: nil, action: :rebase_requested } ]
      )
    end
  end
end
