# frozen_string_literal: true

require "thor"
require_relative "auth_command"
require_relative "default_command"
require_relative "posts/cli"
require_relative "templates/cli"

module Grouse
  class CLI < Thor
    desc "auth", "Add or update a blog in ~/.grouse.yaml"
    def auth
      AuthCommand.new.run
    end

    desc "default [BLOG_NAME]", "Switch the default blog (prompts if no name given)"
    def default(blog_name = nil)
      DefaultCommand.new.run(blog_name)
    end

    desc "post SUBCOMMAND", "Create and publish posts (note, article, bookmark)"
    subcommand "post", Grouse::Posts::CLI

    desc "sync SUBCOMMAND", "Sync Liquid templates with the server (pull, push, watch)"
    subcommand "sync", Grouse::Templates::CLI
  end
end
