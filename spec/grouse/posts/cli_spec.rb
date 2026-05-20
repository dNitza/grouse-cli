# frozen_string_literal: true

require "spec_helper"
require "grouse/posts/cli"
require "grouse/config"

RSpec.describe Grouse::Posts::CLI do
  let(:blog_url)  { "https://test.example.com" }
  let(:token)     { "test-token-123" }
  let(:micropub_url) { "#{blog_url}/micropub" }
  let(:location)  { "https://test.example.com/posts/abc" }

  let(:config) { instance_double(Grouse::Config, url: blog_url, token: token, api_key: token) }

  before do
    allow(Grouse::Config).to receive(:new).and_return(config)
  end

  def stub_micropub(status: 201)
    stub_request(:post, micropub_url)
      .to_return(status: status, headers: {"Location" => location}, body: "")
  end

  # Runs the CLI, swallowing stdout/stderr so test output stays clean.
  # Restores streams even when the CLI calls exit.
  def run(*argv)
    old_out = $stdout
    old_err = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    described_class.start(argv)
  ensure
    $stdout = old_out
    $stderr = old_err
  end

  def last_request_body
    WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last&.body
  end

  # WebMock doesn't match repeated form keys (category%5B%5D=x&category%5B%5D=y)
  # as arrays via hash_including, so we use a block matcher instead.
  def assert_categories(url, *tags)
    expect(a_request(:post, url).with { |req|
      pairs = URI.decode_www_form(req.body)
      pairs.select { |k, _| k == "category[]" }.map(&:last) == tags
    }).to have_been_made
  end

  # ─── authentication ──────────────────────────────────────────────────────────

  describe "authentication" do
    it "sends the token as a Bearer header" do
      stub_micropub
      run("note", "hello")
      expect(a_request(:post, micropub_url).with(headers: {"Authorization" => "Bearer #{token}"})).to have_been_made
    end
  end

  # ─── note ────────────────────────────────────────────────────────────────────

  describe "note" do
    it "posts content as an h-entry" do
      stub_micropub
      run("note", "Hello world")
      expect(a_request(:post, micropub_url).with(body: hash_including(
        "h" => "entry",
        "content" => "Hello world"
      ))).to have_been_made
    end

    it "joins multiple positional arguments into one content string" do
      stub_micropub
      run("note", "hello", "world")
      expect(a_request(:post, micropub_url).with(body: hash_including(
        "content" => "hello world"
      ))).to have_been_made
    end

    it "reads content from stdin when no argument is given" do
      stub_micropub
      old_stdin = $stdin
      $stdin = StringIO.new("piped note\n")
      run("note")
      expect(a_request(:post, micropub_url).with(body: hash_including(
        "content" => "piped note"
      ))).to have_been_made
    ensure
      $stdin = old_stdin
    end

    it "sends tags as category[] params" do
      stub_micropub
      run("note", "--tags", "ruby,web", "tagged note")
      assert_categories(micropub_url, "ruby", "web")
    end

    it "sends post-status=draft when --draft is given" do
      stub_micropub
      run("note", "--draft", "draft note")
      expect(a_request(:post, micropub_url).with(body: hash_including(
        "post-status" => "draft"
      ))).to have_been_made
    end

    it "does not send post-status without --draft" do
      stub_micropub
      run("note", "live note")
      expect(a_request(:post, micropub_url).with(body: hash_including(
        "post-status" => "draft"
      ))).not_to have_been_made
    end

    it "exits when content is empty" do
      expect { run("note") }.to raise_error(SystemExit)
    end

    it "prints the Location URL returned by the server" do
      stub_micropub
      old_out = $stdout
      $stdout = StringIO.new
      described_class.start(["note", "hi"])
      output = $stdout.string
      expect(output).to include(location)
    ensure
      $stdout = old_out
    end

    it "exits on a server error" do
      stub_micropub(status: 422)
      expect { run("note", "bad") }.to raise_error(SystemExit)
    end
  end

  # ─── article ─────────────────────────────────────────────────────────────────

  describe "article" do
    it "posts content with a name (title)" do
      stub_micropub
      run("article", "--title", "My Post", "Some body text")
      expect(a_request(:post, micropub_url).with(body: hash_including(
        "h" => "entry",
        "name" => "My Post",
        "content" => "Some body text"
      ))).to have_been_made
    end

    it "includes mp-slug when --slug is given" do
      stub_micropub
      run("article", "--title", "My Post", "--slug", "my-post", "body")
      expect(a_request(:post, micropub_url).with(body: hash_including(
        "mp-slug" => "my-post"
      ))).to have_been_made
    end

    it "sends tags as category[] params" do
      stub_micropub
      run("article", "--title", "Tagged", "--tags", "ruby,oss", "body")
      assert_categories(micropub_url, "ruby", "oss")
    end

    it "sends post-status=draft when --draft is given" do
      stub_micropub
      run("article", "--title", "Draft", "--draft", "body")
      expect(a_request(:post, micropub_url).with(body: hash_including(
        "post-status" => "draft"
      ))).to have_been_made
    end

    it "reads content from a file when --file is given" do
      stub_micropub
      file = Tempfile.new(["article", ".md"])
      file.write("file body content")
      file.close
      run("article", "--title", "From File", "--file", file.path)
      expect(a_request(:post, micropub_url).with(body: hash_including(
        "content" => "file body content"
      ))).to have_been_made
    ensure
      file&.unlink
    end

    it "exits when --title is missing" do
      expect { run("article", "body text") }.to raise_error(SystemExit)
    end

    it "exits when content is missing" do
      expect { run("article", "--title", "No Body") }.to raise_error(SystemExit)
    end
  end

  # ─── like ────────────────────────────────────────────────────────────────────

  describe "like" do
    let(:liked_url) { "https://example.com/a-great-post" }

    it "posts a like-of entry" do
      stub_micropub
      run("like", liked_url)
      expect(a_request(:post, micropub_url).with(body: hash_including(
        "h" => "entry",
        "like-of" => liked_url
      ))).to have_been_made
    end

    it "prints the Location URL returned by the server" do
      stub_micropub
      old_out = $stdout
      $stdout = StringIO.new
      described_class.start(["like", liked_url])
      output = $stdout.string
      expect(output).to include(location)
    ensure
      $stdout = old_out
    end

    it "exits when URL is missing" do
      expect { run("like") }.to raise_error(SystemExit)
    end
  end

  # ─── bookmark ────────────────────────────────────────────────────────────────

  describe "bookmark" do
    let(:bookmarked_url) { "https://example.com/interesting-post" }

    it "posts a bookmark-of entry" do
      stub_micropub
      run("bookmark", bookmarked_url)
      expect(a_request(:post, micropub_url).with(body: hash_including(
        "h" => "entry",
        "bookmark-of" => bookmarked_url
      ))).to have_been_made
    end

    it "includes name when --name is given" do
      stub_micropub
      run("bookmark", bookmarked_url, "--name", "Great post")
      expect(a_request(:post, micropub_url).with(body: hash_including(
        "name" => "Great post"
      ))).to have_been_made
    end

    it "includes content when --content is given" do
      stub_micropub
      run("bookmark", bookmarked_url, "--content", "My notes on this")
      expect(a_request(:post, micropub_url).with(body: hash_including(
        "content" => "My notes on this"
      ))).to have_been_made
    end

    it "sends tags as category[] params" do
      stub_micropub
      run("bookmark", bookmarked_url, "--tags", "reading,links")
      assert_categories(micropub_url, "reading", "links")
    end

    it "exits when URL is missing" do
      expect { run("bookmark") }.to raise_error(SystemExit)
    end
  end
end
