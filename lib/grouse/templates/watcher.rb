# frozen_string_literal: true

require "listen"

module Grouse
  module Templates
    class Watcher
      def initialize(dir:, client:, output: $stdout)
        @dir    = File.expand_path(dir)
        @client = client
        @output = output
      end

      def start
        @output.puts "Watching #{@dir} for changes. Press Ctrl+C to stop."

        listener = Listen.to(@dir, only: /\.liquid$/) do |modified, added, _removed|
          (modified + added).each { |path| sync_file(path) }
        end

        listener.start
        sleep
      rescue Interrupt
        @output.puts "\nStopped."
      end

      def sync_file(path)
        slug = File.basename(path, ".liquid")
        content = File.read(path)
        @client.update_template(slug, content)
        @output.puts "[#{timestamp}] Synced #{slug}"
      rescue => e
        @output.puts "[#{timestamp}] Error syncing #{slug}: #{e.message}"
      end

      private

      def timestamp
        Time.now.strftime("%H:%M:%S")
      end
    end
  end
end
