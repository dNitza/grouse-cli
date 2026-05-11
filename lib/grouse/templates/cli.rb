# frozen_string_literal: true

require "thor"
require "fileutils"
require_relative "../config"
require_relative "client"
require_relative "watcher"

module Grouse
  module Templates
    class CLI < Thor
      class_option :blog, type: :string, aliases: "-b", desc: "Blog name from ~/.grouse.yaml"

      desc "pull", "Fetch all templates from the server and write to local .liquid files"
      option :output, type: :string, default: "./templates", aliases: "-o",
                      desc: "Directory to write template files into"
      def pull
        dir = File.expand_path(options[:output])
        FileUtils.mkdir_p(dir)

        say "Fetching templates from #{config.url}..."
        templates = client.list_templates

        if templates.empty?
          say "No custom templates found on server. (Default theme templates are used.)"
          return
        end

        templates.each do |t|
          path = File.join(dir, "#{t[:slug]}.liquid")
          File.write(path, t[:content].to_s)
          say "  Pulled #{t[:slug]} → #{path}"
        end

        say "Done. #{templates.count} template(s) pulled."
      rescue => e
        say "Error: #{e.message}", :red
        exit 1
      end

      desc "push", "Push all .liquid files in a directory to the server"
      option :input, type: :string, default: "./templates", aliases: "-i",
                     desc: "Directory to read template files from"
      def push
        dir = File.expand_path(options[:input])
        files = Dir.glob(File.join(dir, "*.liquid"))

        if files.empty?
          say "No .liquid files found in #{dir}", :yellow
          return
        end

        say "Pushing templates to #{config.url}..."
        files.each do |path|
          slug = File.basename(path, ".liquid")
          content = File.read(path)
          client.update_template(slug, content)
          say "  Pushed #{slug}"
        end

        say "Done. #{files.count} template(s) pushed."
      rescue => e
        say "Error: #{e.message}", :red
        exit 1
      end

      desc "watch", "Watch a directory and sync changes to the server on file save"
      option :dir, type: :string, default: "./templates", aliases: "-d",
                   desc: "Directory to watch for .liquid file changes"
      def watch
        dir = File.expand_path(options[:dir])
        FileUtils.mkdir_p(dir)

        say "Pulling current templates before watching..."
        invoke :pull, [], output: dir

        Watcher.new(dir: dir, client: client).start
      rescue => e
        say "Error: #{e.message}", :red
        exit 1
      end

      private

      def config
        @config ||= Grouse::Config.new(blog: options[:blog])
      end

      def client
        @client ||= Client.new(config)
      end
    end
  end
end
