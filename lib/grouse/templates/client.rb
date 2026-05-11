# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Grouse
  module Templates
    class Client
      def initialize(config)
        @config = config
        @base_uri = URI.parse(config.url)
      end

      def list_templates
        body = get("/api/templates")
        JSON.parse(body, symbolize_names: true)[:templates]
      end

      def get_template(slug)
        body = get("/api/templates/#{slug}")
        JSON.parse(body, symbolize_names: true)
      end

      def update_template(slug, content)
        body = put("/api/templates/#{slug}", {page_template: {content: content}})
        JSON.parse(body, symbolize_names: true)
      end

      private

      def get(path)
        request(Net::HTTP::Get.new(path))
      end

      def put(path, data)
        req = Net::HTTP::Put.new(path)
        req["Content-Type"] = "application/json"
        req.body = data.to_json
        request(req)
      end

      def request(req)
        req["Authorization"] = "Bearer #{@config.api_key}"
        req["Accept"] = "application/json"

        http = Net::HTTP.new(@base_uri.host, @base_uri.port)
        http.use_ssl = (@base_uri.scheme == "https")

        res = http.request(req)

        case res.code.to_i
        when 200..299
          res.body
        when 401
          raise "Authentication failed — check your API key"
        when 404
          raise "Not found: #{req.path}"
        when 422
          parsed = JSON.parse(res.body, symbolize_names: true) rescue {}
          raise "Validation error: #{parsed[:error] || parsed[:errors] || res.body}"
        else
          raise "Server error #{res.code}: #{res.body}"
        end
      end
    end
  end
end
