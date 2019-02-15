# frozen_string_literal: true

require 'argot'
require 'argot/cl_utilities'
require 'thor'
require 'json'
require 'yaml'
require 'rsolr'
require 'argot/cl_utilities'
require 'logger'

module Argot
  # The class that executes for the Argot command line utility.
  class CommandLine < Thor
    default_task :full_validate

    no_commands do
      include Argot::Pipelines

      SCHEMA_FILENAME = '.argot-solr-schema.xml'

      def default_schema_locations
        [
          File.join(Dir.pwd, SCHEMA_FILENAME),
          File.join(Dir.home, SCHEMA_FILENAME),
          File.join(__dir__, '..', 'data', 'solr_schema.xml')
        ].map { |f| File.absolute_path(f) }
      end

      def find_schema(location)
        if location
          if location.start_with?('http')
            location + '/schema?wt=schema.xml' unless location.include?('schema.xml')
          else
            schema_file = File.exist?(location) ? location : File.join(__dir__, '..', 'data', location)
            File.open(schema_file)
          end
        else
          default_schema_locations.find { |f| File.exist?(f) }
        end
      end

      def logger
        @logger ||= default_logger
      end

      def default_logger
        l = Logger.new(STDERR)
        l.level = Logger::INFO
        l
      end

      def set_verbose
        logger.level = Logger::DEBUG
      end
    end

    map %w[--version -v] => :__version

    desc '--version, -v', 'print the version'
    def __version
      puts "argot version #{Argot::VERSION}, installed #{File.mtime(__FILE__)}"
    end

    desc 'full_validate [INPUT] [OUTPUT]', 'Validate, flatten, suffix, and check results against the Solr schema'
    method_option   :quiet,
                    type: :boolean,
                    default: true,
                    aliases: '-q',
                    desc: "Don't write anything to STDOUT"
    method_option   :format,
                     type: :string,
                     default: 'text',
                     aliases: '-f',
                     desc: 'Format for error messages [text|json|pretty_json] text, JSON, or indented ("pretty") JSON'
    def full_validate(input = $stdin, output = $stdin)
      options.all = true
      validate(input, output)
    end

    ###############
    # Validate
    ###############
    desc 'validate [INPUT]', 'Validate Argot file converted from MARC (stdin or filename).'

    method_option   :quiet,
                    type: :boolean,
                    default: false,
                    aliases: '-q',
                    desc: "Don't write records to STDOUT"

    method_option   :all,
                    type: :boolean,
                    default: false,
                    aliases: '-a',
                    desc: 'validate, flatten, suffix, and Solr validate results (same as full_validate)'
    method_option    :format,
                     type: :string,
                     default: 'text',
                     aliases: '-f',
                     desc: 'Format for error messages [text|json|pretty_json] text, JSON, or indented ("pretty") JSON'

    method_option   :verbose,
                    type:  :boolean,
                    default:  false,
                    aliases:  '-v',
                    desc:  'display rules and error information'
    def validate(input = $stdin, output = $stdout)
      p = options.all ? everything_pipeline(options) : validate_pipeline(options)
      total = 0
      count = 0
      formatter = formatter(options)
      get_output(output) do |out|
        get_input(input) do |f|
          reader = Argot::Reader.new(f)
          prev_rec = nil
          p.run(reader) do |rec|
            count += 1
            out.write(rec.to_json) unless options.quiet
          end
          total = reader.count
        end
        warn "Found #{count}/#{total} document(s) with errors" if options.verbose
      end
      exit ( total > count  ? 1 : 0)
    end

    ###############
    # Flatten
    ###############
    desc 'flatten <input> <output>', 'Flatten an argot file'
    method_option   :pretty,
                    type:  :boolean,
                    default:  false,
                    aliases:  '-p',
                    desc:  'pretty print resulting json'
    method_option   :flattener_config,
                    default:  '/flattener_config.yml',
                    aliases:  '-t',
                    desc:  'Solr flattener config file'
    def flatten(input=$stdin, output=$stdout)
      p = flatten_pipeline(options)
      formatter = json_formatter(options)
      get_output(output) do |out|
        get_input(input) do |f|
          p.run(Argot::Reader.new(f)) do |rec|
            out.write(formatter.call(rec))
          end
        end
      end
    end

    ###############
    # Suffix
    ###############
    desc 'suffix <input, default stdin> <output, default stdout>', 'Flatten and Suffix an argot file ('
    method_option   :pretty,
                    type:  :boolean,
                    default:  false,
                    aliases:  '-p',
                    desc:  'pretty print resulting json'
    method_option   :fields,
                    default:  '/solr_fields_config.yml',
                    aliases:  '-f',
                    desc:  'Solr fields configuration file'
    method_option   :config,
                    default:  '/solr_suffixer_config.yml',
                    aliases:  '-c',
                    desc:  'Solr suffixer config file'
    method_option   :flattener,
                    default:  '/flattener_config.yml',
                    aliases:  '-t',
                    desc:  'Solr flattener config file'
    def suffix(input = $stdin, output = $stdout)
      p = suffix_pipeline
      fmt = json_formatter(options)
      get_output(output) do |out|
        get_input(input) do |f|
          reader = Argot::Reader.new(f)
          p.run(reader) do |rec|
            out.write(fmt.call(rec))
          end
        end
      end
    end

    desc 'schemaupdate [collection URL]', 'Download a recent version of a schema from a running solr instance'
    method_option :check,
                  aliases: '-c',
                  type: :boolean,
                  desc: 'Download and write to STDOUT, do not save in default location'
    def schemaupdate(url)
      url += '/schema?wt=schema.xml' unless url.include?('/schema?wt=schema.xml')
      logger.info("Downloading from #{url}")
      content = Net::HTTP.get(URI(url))
      puts content && exit(0) if options[:check]
      doc = Nokogiri::XML(content)
      unless doc.errors.empty?
        logger.fatal("Will not save ill-formed document: #{doc.errors}")
        exit(1)
      end
      location = default_schema_locations.first
      File.open(location, 'w') do |f|
        f.write(content)
      end
      puts "Saved new schema to #{location}"
    end

    desc 'solrvalidate [options] <input> <output>', 'Flattens, suffixes, and validates results against Solr schema'
    method_option :schema_location,
                  aliases:  '-s',
                  desc:  'Solr schema to load; if http(s), assumed path to collection.'
    method_option :cull,
                  type: :boolean,
                  aliases: '-c',
                  desc: 'Writes valid records to output, warns about invalid records on STDERR'

    method_option :verbose,
                  type: :boolean
    def solrvalidate(input = $stdin, output = $stdout)
      set_verbose if options[:verbose]
      schema_loc = find_schema(options[:schema_location])
      logger.debug("Default locations: #{default_schema_locations}")
      logger.debug("Loading schema from #{schema_loc}") if options[:verbose]

      schema = Argot::SolrSchema.new(schema_loc)

      all_valid = true
      get_output(output) do |out|
        get_input(input) do |f|
          reader = Argot::Reader.new(f)
          reader.each do |data|
            data = [data] unless data.is_a?(Array)
            data.each do |rec|
              result = schema.analyze(rec)
              if result.empty?
                data.each { |d| out.write(d.to_json) } if options.cull
              else
                all_valid = false
                result['id'] = rec['id']
                warn result.to_json
              end
            end
          end
        end
      end
      exit(1) unless all_valid
    end

    ###############
    # Index into solr
    ###############
    desc 'ingest <input, default STDIN>', 'Flatten, suffix, and ingest an argot file'
    method_option   :solrUrl,
                    default:  'http://localhost:8983/solr/trln',
                    aliases:  '-s',
                    desc:  'Solr endpoint'

    method_option   :interval,
                    default: 500,
                    type: :numeric,
                    aliases: '-i',
                    desc: 'Document add interval'

    method_option   :quiet,
                    type: :boolean,
                    default: false,
                    aliases: '-q',
                    desc: 'Suppress progress on STDOUT'

    method_option   :format,
                    type: :string,
                    default: 'text',
                    aliases: '-f',
                    desc: 'Format for error messages [text|json|pretty_json] text, JSON, or indented ("pretty") JSON'

    method_option   :verbose,
                    type:  :boolean,
                    default:  false,
                    aliases:  '-v',
                    desc:  'display rules and error information'
    def ingest(input = $stdin)
      p = everything_pipeline(options)
      solr = RSolr.connect url: options.solrUrl
      cache = []
      flush = lambda do |commit = false|
        solr.add cache
        print '#' unless options.quiet
        solr.commit if commit
        puts ' commit' if commit && !options.quiet
        cache.clear
      end
      puts "Each '#' represents #{options.interval} documents added" unless options.quiet
      total = count = 0
      get_input(input) do |f|
        reader = Argot::Reader.new(f)
        p.run(reader) do |doc|
          count += 1
          cache << doc
          flush.call if cache.length >= options.interval
        end
        total = reader.count
      end
      flush.call(true)
      puts "Added #{count}/#{total} document(s) [skipped #{total - count}]" unless options.quiet
    end

    desc 'split [options] file1 file2', 'splits input files into output files'
    method_option :output,
                  default:  'argot-files',
                  aliases: '-o',
                  desc: 'Output directory for files' 
    method_option :size,
      type: 'numeric',
      default: 20000,
      aliases: '-s',
      desc: 'maximum record count in each output file'
    method_option :pattern,
      default: Argot::Splitter::DEFAULT_PATTERN,
      aliases: '-p',
      desc: 'Pattern to use when naming output files (%d => count of current file)'
    def split(*files)
      splitter = Argot::Splitter.new(options[:output], chunk_size: options[:size])

      files.each do |filename|
        File.open(filename) do |f|
          parser = Argot::Reader.new(f)
          parser.each do |rec|
            splitter.write(rec)
          end
        end
      end
      splitter.close
    end
  end
end
