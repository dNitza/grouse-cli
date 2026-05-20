# frozen_string_literal: true

require "spec_helper"
require "grouse/default_command"
require "tempfile"
require "fileutils"
require "stringio"

RSpec.describe Grouse::DefaultCommand do
  let(:tmpdir)      { Dir.mktmpdir }
  let(:config_path) { File.join(tmpdir, ".grouse.yaml") }
  let(:output)      { StringIO.new }

  after { FileUtils.rm_rf(tmpdir) }

  let(:two_blogs) do
    {
      "default" => "first",
      "blogs"   => {
        "first"  => {"url" => "https://first.example.com",  "token" => "tok1"},
        "second" => {"url" => "https://second.example.com", "token" => "tok2"}
      }
    }
  end

  def write_config(data)
    File.write(config_path, data.to_yaml)
  end

  def saved_default
    YAML.safe_load(File.read(config_path))["default"]
  end

  def run_with(blog_name: nil, input: "")
    inp = StringIO.new(input + "\n")
    described_class.new(input: inp, output: output, path: config_path).run(blog_name)
  end

  context "with a blog name argument" do
    before { write_config(two_blogs) }

    it "sets the named blog as default" do
      run_with(blog_name: "second")
      expect(saved_default).to eq "second"
    end

    it "prints a confirmation" do
      run_with(blog_name: "second")
      expect(output.string).to include("second")
    end

    it "raises when the blog name does not exist" do
      expect { run_with(blog_name: "missing") }
        .to raise_error(RuntimeError, /missing/)
    end
  end

  context "without a blog name argument (interactive)" do
    before { write_config(two_blogs) }

    it "lists available blogs" do
      run_with(input: "second")
      expect(output.string).to include("first")
      expect(output.string).to include("second")
    end

    it "marks the current default" do
      run_with(input: "second")
      expect(output.string).to match(/first.*current default/i)
    end

    it "sets the blog entered by the user" do
      run_with(input: "second")
      expect(saved_default).to eq "second"
    end

    it "raises when the user enters a blank name" do
      expect { run_with(input: "") }
        .to raise_error(RuntimeError, /No blog name entered/)
    end
  end

  context "when config file does not exist" do
    it "raises a helpful error" do
      expect { run_with(blog_name: "anything") }
        .to raise_error(RuntimeError, /Config file not found/)
    end
  end

  context "when no blogs are configured" do
    before { write_config({"blogs" => {}}) }

    it "raises a helpful error" do
      expect { run_with(blog_name: "anything") }
        .to raise_error(RuntimeError, /No blogs configured/)
    end
  end
end
