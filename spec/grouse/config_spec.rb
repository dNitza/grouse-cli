# frozen_string_literal: true

require "spec_helper"
require "grouse/config"
require "tempfile"
require "fileutils"

RSpec.describe Grouse::Config do
  let(:tmpdir) { Dir.mktmpdir }
  let(:config_path) { File.join(tmpdir, ".grouse.yaml") }

  after { FileUtils.rm_rf(tmpdir) }

  def write_config(data)
    File.write(config_path, data)
  end

  context "with a single blog and no default" do
    before do
      write_config(<<~YAML)
        blogs:
          myblog:
            url: https://myblog.example.com
            token: my-token
      YAML
    end

    it "selects the only blog automatically" do
      config = described_class.new(path: config_path)
      expect(config.blog_name).to eq "myblog"
    end

    it "exposes url and token" do
      config = described_class.new(path: config_path)
      expect(config.url).to eq "https://myblog.example.com"
      expect(config.token).to eq "my-token"
    end

    it "exposes api_key as an alias for token" do
      config = described_class.new(path: config_path)
      expect(config.api_key).to eq "my-token"
    end

    it "strips trailing slash from url" do
      write_config(<<~YAML)
        blogs:
          myblog:
            url: https://myblog.example.com/
            token: my-token
      YAML
      expect(described_class.new(path: config_path).url).to eq "https://myblog.example.com"
    end
  end

  context "with multiple blogs and a default" do
    before do
      write_config(<<~YAML)
        default: second
        blogs:
          first:
            url: https://first.example.com
            token: first-token
          second:
            url: https://second.example.com
            token: second-token
      YAML
    end

    it "selects the default blog" do
      config = described_class.new(path: config_path)
      expect(config.blog_name).to eq "second"
      expect(config.url).to eq "https://second.example.com"
      expect(config.token).to eq "second-token"
    end

    it "selects a specific blog when blog: is given" do
      config = described_class.new(blog: "first", path: config_path)
      expect(config.blog_name).to eq "first"
      expect(config.url).to eq "https://first.example.com"
    end

    it "raises when the requested blog does not exist" do
      expect { described_class.new(blog: "missing", path: config_path) }
        .to raise_error(RuntimeError, /missing/)
    end
  end

  context "with multiple blogs and no default" do
    before do
      write_config(<<~YAML)
        blogs:
          alpha:
            url: https://alpha.example.com
            token: alpha-token
          beta:
            url: https://beta.example.com
            token: beta-token
      YAML
    end

    it "raises when no blog is selected" do
      expect { described_class.new(path: config_path) }
        .to raise_error(RuntimeError, /No blog selected/)
    end

    it "succeeds when a blog is explicitly specified" do
      config = described_class.new(blog: "beta", path: config_path)
      expect(config.url).to eq "https://beta.example.com"
    end
  end

  context "when config file is missing" do
    it "raises a helpful error" do
      expect { described_class.new(path: "/nonexistent/.grouse.yaml") }
        .to raise_error(RuntimeError, /Config file not found/)
    end
  end

  context "when a blog entry is incomplete" do
    it "raises when url is missing" do
      write_config(<<~YAML)
        blogs:
          myblog:
            token: my-token
      YAML
      expect { described_class.new(path: config_path) }
        .to raise_error(RuntimeError, /missing 'url'/)
    end

    it "raises when token is missing" do
      write_config(<<~YAML)
        blogs:
          myblog:
            url: https://myblog.example.com
      YAML
      expect { described_class.new(path: config_path) }
        .to raise_error(RuntimeError, /missing 'token'/)
    end
  end
end
