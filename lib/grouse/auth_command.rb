# frozen_string_literal: true

require "yaml"
require_relative "config"

module Grouse
  class AuthCommand
    CONFIG_PATH = Grouse::Config::DEFAULT_PATH

    def initialize(input: $stdin, output: $stderr, path: CONFIG_PATH)
      @input  = input
      @output = output
      @path   = path
    end

    def run
      name  = prompt_required("Blog name: ")
      url   = prompt_required("URL (e.g. https://myblog.example.com): ")
      token = prompt_required("Token: ")

      data          = load_existing
      data["blogs"] ||= {}
      existing      = data["blogs"].key?(name)

      data["blogs"][name] = {"url" => url.chomp("/"), "token" => token}

      if data["blogs"].size == 1
        data["default"] = name
      elsif !existing && prompt_yes?("Set '#{name}' as default blog? [y/N]: ")
        data["default"] = name
      end

      save(data)

      say "Blog '#{name}' #{existing ? "updated" : "added"} in #{@path}."
      say "Default blog: #{data["default"]}." if data["default"]
    end

    private

    def prompt(text)
      @output.print text
      @input.gets&.chomp&.strip || ""
    end

    def prompt_required(text)
      loop do
        value = prompt(text)
        return value unless value.empty?

        say "  This field is required."
      end
    end

    def prompt_yes?(text)
      prompt(text).downcase.start_with?("y")
    end

    def say(text)
      @output.puts text
    end

    def load_existing
      return {} unless File.exist?(@path)
      YAML.safe_load(File.read(@path)) || {}
    end

    def save(data)
      File.write(@path, data.to_yaml)
    end
  end
end
