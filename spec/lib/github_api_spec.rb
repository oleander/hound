require "spec_helper"
require "attr_extras"
require "lib/github_api"
require "json"

describe GitHubApi do
  before { stub_const("Hound::GITHUB_TOKEN", "token") }

  describe "#repos" do
    it "fetches all repos from GitHub" do
      token = "something"
      api = GitHubApi.new(token)
      stub_repos_requests(token)

      repos = api.repos

      expect(repos.size).to eq 2
    end
  end

  describe "#file_contents" do
    context "used multiple times with same arguments" do
      it "requests file content once" do
        client = double("Octokit::Client", contents: "filecontent")
        allow(Octokit::Client).to receive(:new).and_return(client)
        token = "authtoken"
        github = GitHubApi.new(token)
        repo = "jimtom/wow"
        filename = ".hound.yml"
        sha = "abc123"

        contents = github.file_contents(repo, filename, sha)
        same_contents = github.file_contents(repo, filename, sha)

        expect(contents).to eq "filecontent"
        expect(same_contents).to eq contents
        expect(Octokit::Client).to have_received(:new).with(
          bearer_token: token,
          auto_paginate: true,
        )
        expect(client).to have_received(:contents).with(
          repo,
          path: filename,
          ref: sha
        ).once
      end
    end
  end

  describe "#remove_hook" do
    it "removes pull request web hook" do
      hook_id = "123"
      stub_hook_removal_request(repo_name, hook_id)
      api = GitHubApi.new(Hound::GITHUB_TOKEN)

      response = api.remove_hook(repo_name, hook_id)

      expect(response).to be_truthy
    end

    it "yields given block" do
      hook_id = "123"
      stub_hook_removal_request(repo_name, hook_id)
      api = GitHubApi.new(Hound::GITHUB_TOKEN)
      yielded = false

      api.remove_hook(repo_name, hook_id) do
        yielded = true
      end

      expect(yielded).to eq true
    end
  end

  describe "#pull_request_files" do
    it "returns changed files in a pull request" do
      api = GitHubApi.new(Hound::GITHUB_TOKEN)
      pull_request = double("PullRequest", repo_name: repo_name)
      pr_number = 123
      stub_pull_request_files_request(pull_request.repo_name, pr_number)

      files = api.pull_request_files(pull_request.repo_name, pr_number)

      expect(files.size).to eq(1)
      expect(files.first.filename).to eq "spec/models/style_guide_spec.rb"
    end
  end

  describe "#create_pull_request_review" do
    it "adds review comments to GitHub pull request" do
      api = GitHubApi.new("authtoken")
      pull_request_number = 2
      comments = [
        { path: "test/test.rb", position: 10, body: "test comment 1" },
        { path: "test/test.rb", position: 15, body: "test comment 2" },
      ]
      body = "something bad happened"
      request = stub_review_request(
        repo_name,
        pull_request_number,
        comments,
        body,
      )

      api.create_pull_request_review(
        repo_name,
        pull_request_number,
        comments,
        body,
      )

      expect(request).to have_been_requested
    end
  end

  describe "#pull_request_comments" do
    it "returns comments added to pull request" do
      api = GitHubApi.new(Hound::GITHUB_TOKEN)
      pull_request = double("PullRequest", repo_name: repo_name)
      pull_request_id = 253
      expected_comment = "Line is too long."
      stub_pull_request_comments_request(
        pull_request.repo_name,
        pull_request_id,
        "houndci-bot",
      )

      comments = api.pull_request_comments(
        pull_request.repo_name,
        pull_request_id
      )

      expect(comments.size).to eq(4)
      expect(comments.first.body).to eq expected_comment
    end
  end

  describe "#create_pending_status" do
    it "makes request to GitHub for creating a pending status" do
      api = GitHubApi.new(Hound::GITHUB_TOKEN)
      request = stub_status_request(
        "test/repo",
        "sha",
        "pending",
        "description"
      )

      api.create_pending_status("test/repo", "sha", "description")

      expect(request).to have_been_requested
    end
  end

  describe "#create_success_status" do
    it "makes request to GitHub for creating a success status" do
      api = GitHubApi.new(Hound::GITHUB_TOKEN)
      request = stub_status_request(
        "test/repo",
        "sha",
        "success",
        "description"
      )

      api.create_success_status("test/repo", "sha", "description")

      expect(request).to have_been_requested
    end
  end

  describe "#create_error_status" do
    it "makes request to GitHub for creating an error status" do
      api = GitHubApi.new(Hound::GITHUB_TOKEN)
      request = stub_status_request(
        "test/repo",
        "sha",
        "error",
        "description"
      )

      api.create_error_status("test/repo", "sha", "description")

      expect(request).to have_been_requested
    end
  end

  describe "#remove_collaborator" do
    it "makes a request to GitHub" do
      username = "houndci"
      api = GitHubApi.new(token)
      request = stub_remove_collaborator_request(username, repo_name, token)

      api.remove_collaborator(repo_name, username)

      expect(request).to have_been_requested
    end
  end

  def token
    "github_token"
  end

  def repo_name
    "foo/bar"
  end
end
