# frozen_string_literal: true

require "spec_helper"
require "grouse/config"
require "grouse/templates/client"

RSpec.describe Grouse::Templates::Client do
  let(:config) { instance_double(Grouse::Config, url: "https://myblog.example.com", api_key: "test-key") }
  let(:client) { described_class.new(config) }

  def stub_get(path, response_body, status: 200)
    stub_request(:get, "https://myblog.example.com#{path}")
      .with(headers: {"Authorization" => "Bearer test-key"})
      .to_return(status: status, body: response_body.to_json, headers: {"Content-Type" => "application/json"})
  end

  def stub_put(path, request_body, response_body, status: 200)
    stub_request(:put, "https://myblog.example.com#{path}")
      .with(
        body: request_body.to_json,
        headers: {"Authorization" => "Bearer test-key", "Content-Type" => "application/json"}
      )
      .to_return(status: status, body: response_body.to_json, headers: {"Content-Type" => "application/json"})
  end

  describe "#list_templates" do
    it "returns array of template hashes" do
      stub_get("/api/templates", {templates: [{slug: "home", content: "<h1>Hello</h1>"}]})

      result = client.list_templates
      expect(result).to eq [{slug: "home", content: "<h1>Hello</h1>"}]
    end

    it "raises on 401" do
      stub_get("/api/templates", {error: "unauthorized"}, status: 401)
      expect { client.list_templates }.to raise_error(/Authentication failed/)
    end
  end

  describe "#get_template" do
    it "returns the template hash" do
      stub_get("/api/templates/home", {slug: "home", content: "{{ post.name }}"})

      result = client.get_template("home")
      expect(result[:slug]).to eq "home"
      expect(result[:content]).to eq "{{ post.name }}"
    end

    it "raises on 404" do
      stub_get("/api/templates/missing", {error: "not found"}, status: 404)
      expect { client.get_template("missing") }.to raise_error(/Not found/)
    end
  end

  describe "#update_template" do
    it "sends content to the correct endpoint and returns response" do
      stub_put(
        "/api/templates/home",
        {page_template: {content: "<h1>Updated</h1>"}},
        {slug: "home", content: "<h1>Updated</h1>"}
      )

      result = client.update_template("home", "<h1>Updated</h1>")
      expect(result[:slug]).to eq "home"
      expect(result[:content]).to eq "<h1>Updated</h1>"
    end

    it "raises on 422 with error message" do
      stub_put(
        "/api/templates/bad",
        {page_template: {content: "x"}},
        {error: "invalid slug 'bad'"},
        status: 422
      )
      expect { client.update_template("bad", "x") }.to raise_error(/invalid slug/)
    end

    it "raises on 401" do
      stub_put(
        "/api/templates/home",
        {page_template: {content: "x"}},
        {error: "unauthorized"},
        status: 401
      )
      expect { client.update_template("home", "x") }.to raise_error(/Authentication failed/)
    end
  end
end
