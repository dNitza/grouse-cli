# frozen_string_literal: true

require "spec_helper"
require "grouse/auth_command"
require "tempfile"
require "fileutils"
require "stringio"

RSpec.describe Grouse::AuthCommand do
  let(:tmpdir)      { Dir.mktmpdir }
  let(:config_path) { File.join(tmpdir, ".grouse.yaml") }
  let(:output)      { StringIO.new }

  after { FileUtils.rm_rf(tmpdir) }

  def run_with(input_lines)
    input = StringIO.new(input_lines.join("\n") + "\n")
    described_class.new(input: input, output: output, path: config_path).run
  end

  def saved_config
    YAML.safe_load(File.read(config_path))
  end

  context "adding the first blog" do
    it "saves url and token under the blog name" do
      run_with(["myblog", "https://myblog.example.com", "secret-token"])

      expect(saved_config["blogs"]["myblog"]).to eq(
        "url"   => "https://myblog.example.com",
        "token" => "secret-token"
      )
    end

    it "strips a trailing slash from the url" do
      run_with(["myblog", "https://myblog.example.com/", "secret-token"])
      expect(saved_config["blogs"]["myblog"]["url"]).to eq "https://myblog.example.com"
    end

    it "automatically sets the first blog as default without prompting" do
      run_with(["myblog", "https://myblog.example.com", "secret-token"])
      expect(saved_config["default"]).to eq "myblog"
    end

    it "prints a confirmation message" do
      run_with(["myblog", "https://myblog.example.com", "secret-token"])
      expect(output.string).to include("myblog")
      expect(output.string).to include("added")
    end
  end

  context "adding a second blog" do
    before do
      File.write(config_path, {
        "default" => "first",
        "blogs"   => {"first" => {"url" => "https://first.example.com", "token" => "first-token"}}
      }.to_yaml)
    end

    it "adds the new blog without removing the existing one" do
      run_with(["second", "https://second.example.com", "second-token", "n"])

      expect(saved_config["blogs"].keys).to contain_exactly("first", "second")
    end

    it "keeps the existing default when user declines" do
      run_with(["second", "https://second.example.com", "second-token", "n"])
      expect(saved_config["default"]).to eq "first"
    end

    it "updates the default when user confirms" do
      run_with(["second", "https://second.example.com", "second-token", "y"])
      expect(saved_config["default"]).to eq "second"
    end
  end

  context "updating an existing blog" do
    before do
      File.write(config_path, {
        "default" => "myblog",
        "blogs"   => {"myblog" => {"url" => "https://old.example.com", "token" => "old-token"}}
      }.to_yaml)
    end

    it "overwrites the url and token" do
      run_with(["myblog", "https://new.example.com", "new-token"])

      expect(saved_config["blogs"]["myblog"]).to eq(
        "url"   => "https://new.example.com",
        "token" => "new-token"
      )
    end

    it "does not prompt for default when updating an existing blog" do
      run_with(["myblog", "https://new.example.com", "new-token"])
      # no extra input consumed — if it prompted for default it would hang/error
      expect(saved_config["default"]).to eq "myblog"
    end

    it "prints 'updated' in the confirmation" do
      run_with(["myblog", "https://new.example.com", "new-token"])
      expect(output.string).to include("updated")
    end
  end

  context "when a required field is left blank" do
    it "re-prompts until a value is given" do
      # blank name twice, then valid inputs
      run_with(["", "", "myblog", "https://myblog.example.com", "secret-token"])
      expect(saved_config["blogs"].keys).to include("myblog")
    end
  end
end
