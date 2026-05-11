# frozen_string_literal: true

require "spec_helper"
require "grouse/templates/client"
require "grouse/templates/watcher"

RSpec.describe Grouse::Templates::Watcher do
  let(:client) { instance_double(Grouse::Templates::Client) }
  let(:output) { StringIO.new }
  let(:tmpdir) { Dir.mktmpdir }
  let(:watcher) { described_class.new(dir: tmpdir, client: client, output: output) }

  after { FileUtils.rm_rf(tmpdir) }

  describe "#sync_file" do
    it "reads the file and calls update_template with slug derived from filename" do
      path = File.join(tmpdir, "home.liquid")
      File.write(path, "<h1>Hello</h1>")
      allow(client).to receive(:update_template).with("home", "<h1>Hello</h1>")

      watcher.sync_file(path)

      expect(client).to have_received(:update_template).with("home", "<h1>Hello</h1>")
      expect(output.string).to match(/Synced home/)
    end

    it "logs an error message when the client raises" do
      path = File.join(tmpdir, "post.liquid")
      File.write(path, "content")
      allow(client).to receive(:update_template).and_raise("Authentication failed")

      watcher.sync_file(path)

      expect(output.string).to match(/Error syncing post: Authentication failed/)
    end
  end

  describe "#start" do
    it "sets up a Listen watcher on the directory for .liquid files" do
      listener = instance_double(Listen::Listener)
      allow(listener).to receive(:start)
      allow(Listen).to receive(:to)
        .with(File.expand_path(tmpdir), only: /\.liquid$/)
        .and_yield([], [], [])
        .and_return(listener)
      allow(watcher).to receive(:sleep).and_raise(Interrupt)

      watcher.start

      expect(Listen).to have_received(:to).with(File.expand_path(tmpdir), only: /\.liquid$/)
      expect(output.string).to include("Watching")
      expect(output.string).to include("Stopped")
    end
  end
end
