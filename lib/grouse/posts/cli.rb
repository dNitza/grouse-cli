# frozen_string_literal: true

require "thor"
require "net/http"
require "uri"
require "tempfile"
require_relative "../config"

module Grouse
  module Posts
    class CLI < Thor
      class_option :blog, type: :string, aliases: "-b", desc: "Blog name from ~/.grouse.yaml"
      desc "note [CONTENT]", "Publish a short note (content from arg, stdin, or $EDITOR)"
      option :tags,  type: :string,  aliases: "-t", desc: "Comma-separated tags"
      option :draft, type: :boolean, default: false, desc: "Save as draft"
      def note(*words)
        content = read_content(words)
        die("Content required: pass as argument or pipe via stdin") if content.nil? || content.strip.empty?

        params = [["h", "entry"], ["content", content.strip]]
        parse_tags(options[:tags]).each { |t| params << ["category[]", t] }
        params << ["post-status", "draft"] if options[:draft]

        post_micropub(params)
      end

      desc "article [CONTENT]", "Publish a long-form article"
      option :title,       type: :string,  aliases: "-T", desc: "Article title"
      option :slug,        type: :string,  aliases: "-s", desc: "Post slug (auto-generated if blank)"
      option :tags,        type: :string,  aliases: "-t", desc: "Comma-separated tags"
      option :file,        type: :string,  aliases: "-f", desc: "Read content from file"
      option :draft,       type: :boolean, default: false, desc: "Save as draft"
      option :interactive, type: :boolean, aliases: "-i", default: false, desc: "Prompt for all fields"
      def article(*words)
        if options[:interactive]
          base = {
            title:   options[:title],
            slug:    options[:slug],
            tags:    parse_tags(options[:tags]),
            draft:   options[:draft],
            content: read_content(words, file: options[:file])
          }
          fields = interactive_article_fields(base)
        else
          die("--title is required for article") unless options[:title] && !options[:title].empty?
          content = read_content(words, file: options[:file])
          die("Content required: pass as argument, --file, or pipe via stdin") if content.nil? || content.strip.empty?
          fields = {
            title:        options[:title],
            slug:         options[:slug],
            tags:         parse_tags(options[:tags]),
            draft:        options[:draft],
            content:      content,
            published_at: nil
          }
        end

        params = [["h", "entry"], ["name", fields[:title]], ["content", fields[:content].strip]]
        params << ["mp-slug", fields[:slug]]         if fields[:slug] && !fields[:slug].empty?
        params << ["published_at", fields[:published_at]] if fields[:published_at] && !fields[:published_at].empty?
        fields[:tags].each { |t| params << ["category[]", t] }
        params << ["post-status", "draft"] if fields[:draft]

        post_micropub(params)
      end

      desc "like URL", "Like a post or page"
      def like(url = nil)
        die("URL is required: grouse post like URL") unless url && !url.empty?

        params = [["h", "entry"], ["like-of", url]]

        post_micropub(params)
      end

      desc "bookmark URL", "Save a bookmark"
      option :name,    type: :string, aliases: "-n", desc: "Bookmark title"
      option :tags,    type: :string, aliases: "-t", desc: "Comma-separated tags"
      option :content, type: :string, aliases: "-c", desc: "Optional notes"
      def bookmark(url = nil)
        die("URL is required: grouse post bookmark URL [options]") unless url && !url.empty?

        params = [["h", "entry"], ["bookmark-of", url]]
        params << ["name", options[:name]]    if options[:name]
        params << ["content", options[:content]] if options[:content]
        parse_tags(options[:tags]).each { |t| params << ["category[]", t] }

        post_micropub(params)
      end

      private

      def config
        @config ||= Grouse::Config.new(blog: options[:blog])
      end

      def die(msg)
        say msg, :red
        exit 1
      end

      def parse_tags(raw)
        return [] if raw.nil? || raw.empty?
        raw.split(",").map(&:strip)
      end

      def read_content(argv_rest, file: nil)
        if !argv_rest.empty?
          argv_rest.join(" ")
        elsif file
          File.read(file)
        elsif !$stdin.tty?
          $stdin.read.chomp
        end
      end

      def prompt(text)
        $stderr.print text
        $stdin.gets&.chomp || ""
      end

      def prompt_content
        editor = ENV["VISUAL"] || ENV["EDITOR"]
        if editor
          tmp = Tempfile.new(["grouse-draft", ".md"])
          system(editor, tmp.path)
          body = File.read(tmp.path).strip
          tmp.unlink
          die("Content is required — editor was empty") if body.empty?
          body
        else
          $stderr.puts "Content (end with a line containing only '---'):"
          lines = []
          while (line = $stdin.gets)
            break if line.chomp == "---"
            lines << line
          end
          body = lines.join.strip
          die("Content is required") if body.empty?
          body
        end
      end

      def interactive_article_fields(options)
        title = options[:title]
        if title.nil? || title.empty?
          loop do
            title = prompt("Title: ").strip
            break unless title.empty?
            $stderr.puts "Title is required."
          end
        end

        slug = options[:slug]
        if slug.nil? || slug.empty?
          slug = prompt("Slug (blank = auto-generate): ").strip
        end

        tags = options[:tags] || []
        if tags.empty?
          raw = prompt("Tags (comma-separated, blank = none): ").strip
          tags = raw.empty? ? [] : raw.split(",").map(&:strip)
        end

        draft = options[:draft]
        published_at = nil
        unless draft
          date_input = prompt("Publish date (ISO 8601, blank = now, 'draft' = draft): ").strip
          if date_input.downcase == "draft"
            draft = true
          elsif !date_input.empty?
            published_at = date_input
          end
        end

        content = options[:content]
        if content.nil? || content.strip.empty?
          content = prompt_content
        end

        { title:, slug:, tags:, draft:, published_at:, content: }
      end

      def post_micropub(params)
        uri = URI.parse(config.url + "/micropub")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"

        req = Net::HTTP::Post.new(uri.request_uri)
        req["Authorization"] = "Bearer #{config.token}"
        req["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form(params)

        res = http.request(req)

        case res.code
        when "201"
          puts res["Location"]
        else
          die "Error #{res.code}: #{res.body}"
        end
      end
    end
  end
end
