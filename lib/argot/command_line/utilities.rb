# frozen_string_literal: true
require 'redis'
require 'net/http'

module Argot
  class CommandLine
    # helper methods for commandline operations
    module Utilities
      # used to test whether we are running inside a container
      # some utilities may want to use different default URLs
      def in_container?
        File.exist?('/.dockerenv') || File.exist?('/run/.containerenv')
      end

      # connects to redis (if available) using standard fallbacks
      def redis_connect(options)
        return options[:redis] if options.include?(:redis)
        # fallback for running under docker-compose
        backup_url = 'redis://host.containers.internal:6379/0'
        # put REDIS_URL at the front of the line, if set
        urls = [ENV['REDIS_URL'], options[:redis_url]].compact
        urls << backup_url if in_container? and options[:redis_url].include?('localhost')

        redis = urls.map { |u| Redis.new(url: u) }.find { |r| ping_redis(r, options) }

        if redis.nil?
          warn "Redis not available at #{urls}"
          exit(1)
        end
        warn "connected to redis at #{redis.id}" if options[:verbose]
        redis
      end

      # Ensures a #read able input 
      # @param [String, #read] input a filename or IO-style object.
      #   if nil, `$stdin` is used.
      # @return #read
      # @yieldparam [#read]
      def get_input(input = nil)
        input = $stdin if input.nil? || (input == '-')
        input = File.open(input, 'r') unless input.respond_to?(:read)
        if block_given?
          begin
            yield input
          ensure
            input.close if input.respond_to?(:close) && (input != $stdin)
          end
        end
        input
      end

      # Ensures a #read able output
      # @param [String, #write] output a filename or IO-style object
      #   if `nil`, `$stdout` is used
      #  @return #write
      #  @yieldparam [#write]
      def get_output(output = nil)
        output = $stdout if output.nil?
        output = File.open(output, 'w') unless output.respond_to?(:write)
        if block_given?
          begin
            yield output
          ensure
            output.close unless output == $stdout
          end
        else
          output
        end
      end

      # Gets a formatter for validation results
      # @param options [Thor::MethodOptions] method options from Thor
      # @return [#call(result)] a callable that returns a String.
      def formatter(options)
        case options[:format]
        when 'json'
          JSON.method(:generate)
        when 'pretty_json'
          JSON.method(:pretty_generate)
        else
          text_formatter(verbose: options[:verbose])
        end
      end

      # Gets either a plain or 'pretty' JSON formatter
      def json_formatter(options = { pretty: false })
        options[:pretty] ? JSON.method(:pretty_generate) : JSON.method(:generate)
      end

      # Gets a reporter for validation results.
      # @return 
      def validation_reporter(options)
        formatter = formatter(options)
        lambda do |rec, results|
          if options[:verbose]
            errdoc = {
              id: rec.fetch('id', '<unknown id>'),
              msg: results.first_error,
              errors: []
            }
            results.errors.each_with_object(errdoc) do |err, ed|
              ed[:errors] << err
            end
            warn formatter.call(errdoc)
          else
            warn "Document #{rec.fetch('id', '<unknown id>')} skipped (#{results.first_error})"
          end
          false
        end
      end

      def text_formatter(options = { verbose: false })
        lambda do |errdoc|
          msgs = ["Document #{errdoc[:id]} skipped: #{errdoc[:msg]}"]
          if options[:verbose]
            errdoc[:errors].each do |err|
              msgs << "\t#{err[:rule]}"
              err[:errors].each do |em|
                msgs << "\t\t#{em}"
              end
            end
          end
          msgs.join("\n")
        end
      end

      # POSTs the contents of a file to Solr's JSON docuemnt update 
      # handler
      # @param filename the path to a file containing JSON that Solr
      #        can ingest directly
      # @param url the URL to the Solr core or collection to be updated
      # @return a Hash with :success, :body, :response keys indicating
      #         success of the update, the body of the HTTP response, and
      #          the response itself (for clients that want to do detailed
      #          inspection)
      def post_to_solr(filename, url)
        the_uri = URI(if url.end_with?('/update/json/docs')
                        url
                      else
                        "#{url.sub(%r{/$}, '')}/update/json/docs"
                      end)

        File.open(filename) do |f|
          req = Net::HTTP::Post.new(the_url)
          req.body_stream = f
          req['Content-Type'] = 'application/json'
          req['Content-Length'] = File.size(filename)
          Net::HTTP.start(the_uri.hostname, the_uri.port, use_ssl: the_uri.start_with?('https://')) do |http|
            resp = http.request(req)
            return { success: resp.is_a?(Net::HTTPOK), body: resp.body, response: resp }
          end
        end
      end

      private

      def ping_redis(redis, options = {})
        redis.ping
        true
      rescue Redis::CannotConnectError
        warn "no redis available at #{redis.id}" if options[:verbose]
        false
      end
    end
  end
end
