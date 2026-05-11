# frozen_string_literal: true

require "yaml"

module Grouse
  class Config
    DEFAULT_PATH = File.expand_path("~/.grouse.yaml")

    attr_reader :url, :token, :blog_name

    alias_method :api_key, :token

    def initialize(blog: nil, path: DEFAULT_PATH)
      data = load_file(path)
      blogs = data["blogs"] || {}

      @blog_name = blog || data["default"] || single_blog_name(blogs)
      raise "No blog selected. Specify --blog NAME or set 'default:' in #{path}." unless @blog_name
      raise "Blog '#{@blog_name}' not found in #{path}." unless blogs.key?(@blog_name)

      blog_data = blogs[@blog_name]
      @url   = blog_data["url"]&.chomp("/") or raise "Blog '#{@blog_name}' is missing 'url' in #{path}."
      @token = blog_data["token"]           or raise "Blog '#{@blog_name}' is missing 'token' in #{path}."
    end

    private

    def load_file(path)
      raise "Config file not found: #{path}\nCreate ~/.grouse.yaml with your blog credentials." unless File.exist?(path)
      YAML.safe_load(File.read(path)) || {}
    end

    def single_blog_name(blogs)
      blogs.keys.first if blogs.size == 1
    end
  end
end
