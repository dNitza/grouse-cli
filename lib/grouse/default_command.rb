# frozen_string_literal: true

require "yaml"
require_relative "config"

module Grouse
  class DefaultCommand
    CONFIG_PATH = Grouse::Config::DEFAULT_PATH

    def initialize(input: $stdin, output: $stderr, path: CONFIG_PATH)
      @input  = input
      @output = output
      @path   = path
    end

    def run(blog_name = nil)
      data  = load_config
      blogs = data["blogs"] || {}

      raise "No blogs configured. Run `grouse auth` to add one." if blogs.empty?

      blogs_array = blogs.to_a

      name = blog_name || blogs_array[prompt_choice(blogs, data["default"]).to_i - 1][0]

      raise "Blog '#{name}' not found. Available: #{blogs.keys.join(", ")}" unless blogs.key?(name)

      data["default"] = name
      save(data)

      say "Default blog set to '#{name}'."
    end

    private

    def prompt_choice(blogs, current_default)
      say "Available blogs (enter a number):"
      blogs.each_key.each_with_index do |name, index|
        marker = name == current_default ? " (current default)" : ""
        say "#{index + 1}.  #{name}#{marker}"
      end
      say ""
      @output.print "Switch default to: "
      value = @input.gets&.chomp&.strip || ""
      raise "No blog name entered." if value.empty?
      value
    end

    def say(text)
      @output.puts text
    end

    def load_config
      raise "Config file not found: #{@path}\nRun `grouse auth` to add a blog." unless File.exist?(@path)
      YAML.safe_load(File.read(@path)) || {}
    end

    def save(data)
      File.write(@path, data.to_yaml)
    end
  end
end
