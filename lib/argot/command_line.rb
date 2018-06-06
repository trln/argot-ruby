# frozen_string_literal: true

require 'argot'
require 'thor'
require 'json'
require 'yaml'
require 'rsolr'

module Argot
  # Utility for creating pipelines to process records
  class Pipelines
    DATA_LOAD_PATH = File.expand_path('../data', __dir__)

    def self.configuration_paths(options)
      {
        flattener_config_path: YAML.load_file(File.join(DATA_LOAD_PATH, options.flattener_config)),
        fields_path: File.join(DATA_LOAD_PATH, options.fields)
      }
    end

    def self.everything(_options = {})
      validator = Argot::Validator.new
      flattener = Argot::Flattener.new
      suffixer = Argot::Suffixer.new
      schema = Argot::SolrSchema.new
      solr_validator = lambda do |rec|
        res = schema.analyze(rec)
        warn res.to_json unless res.empty?
        res.empty?
      end

      Argot::Pipeline.setup do
        filter { validator.as_block }
        transformer { flattener.as_block }
        suffixer { suffixer.as_block }
        filter { solr_validator }
      end
    end
  end

  # The class that executes for the Argot command line utility.
  class CommandLine < Thor
    default_task :full_validate

    no_commands do
      # Utility wrapper for producing a `:read` able object
      # based on a range of possible argument types.
      # @param input [`:read`, String]  if `nil`, or the string `-`,
      # result is $stdin; if `:read`, result is the original argument,
      # if a String other than `-`, result is an opened File handle.
      # @yield `:read`
      # @return `:read`
      def get_input(input = nil)
        input = $stdin if input.nil? or input == '-'
        input = File.open(input, 'r') unless input.respond_to?(:read)
        if block_given?
          begin
            yield input
          ensure
            input.close if input.respond_to?(:close) and input != $stdin
          end
        else
          input
        end
      end

      def get_output(output = nil)
        output = $stdout if output.nil?
        output = File.open(output,'w') unless output.respond_to?(:write)
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

      def json_formatter(options = { pretty: false })
        options[:pretty] ? JSON.method(:pretty_generate) : JSON.method(:generate)
      end
    end

    map %w[--version -v] => :__version

    desc '--version, -v', 'print the version'
    def __version
      puts "argot version #{Argot::VERSION}, installed #{File.mtime(__FILE__)}"
    end

    desc 'full_validate [INPUT] [OUTPUT]', 'Validate, flatten, suffix, and check results for Solr validity'
    method_option   :quiet,
                    type: :boolean,
                    default: true,
                    aliases: '-q',
                    desc: "Don't write anything to STDOUT"
    def full_validate(input = nil, output = nil)
      pipeline = Pipelines.everything(options)
      get_output(output) do |out|
        get_input(input) do |f|
          pipeline.process(Argot::Reader.new(f)) do |rec|
            out.write(rec.to_json) unless options.quiet
          end
        end
      end
    end

    ###############
    # Validate
    ###############
    desc 'validate [INPUT]', 'Validate Argot file converted from MARC (stdin or filename).'
    method_option   :rules,
                    type: :string,
                    default: '',
                    aliases:  '-r',
                    desc:  'path to a rules file. Default is lib/data/rules.yml'

    method_option   :cull,
                    type: :boolean,
                    default: false,
                    aliases: '-c',
                    desc: "writes documents that pass validation to output, omitting failed
                          documents.  Validation errors to STDERR"
    method_option   :verbose,
                    type:  :boolean,
                    default:  false,
                    aliases:  '-v',
                    desc:  'display rules and error information'
    def validate(input = nil)
      rules_file = options.rules.empty? ? [] : [options.rules]
      validator = Argot::Validator.from_files(rules_file)
      count = 0
      get_output(output) do |out|
        process_json(input) do |doc|
          valid = validator.valid?(doc)
          if valid.errors?
            count += 1
            warn "Document #{doc.fetch('id', '<no id found>')} will be skipped:"
            if options.verbose || options.cull
              valid.errors.each do |error|
                warn "#{error[:rule]}:"
                error[:errors].each do |e|
                  warn "\t  - #{e}"
                end
              end
            end
          elsif options.cull
            out.write(doc.to_json)
          end
        end
        warn "Found #{count} document(s) with errors" if options.verbose || options.cull
      end
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
      flattener = Argot::Flattener.new
      get_output(output) do |out|
        fmt = json_formatter(options)
        get_input(input) do |f|
          f.each_line.map { |x| JSON.parse(x) }.each do |rec|
            out.write( fmt.call(flattener.process(rec)) )
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
      data_load_path = File.expand_path('../data', __dir__)
      config = YAML.load_file(data_load_path + options.config)
      fields = YAML.load_file(data_load_path + options.fields)
      flattener_config = YAML.load_file(data_load_path + options.flattener)
      results = []
      suffixer = Argot::Suffixer.new(config, fields)
      get_input(input) do |f|
        f.each_line do |line|
          doc = JSON.parse(line)
          flattened = Argot::Flattener.process(doc, flattener_config)
          results << suffixer.process(flattened)
        end
      end
      return if results.empty?
      get_output(output) do |f|
        fmt = json_formatter(options)
        results.each { |rec| f.puts fmt.call(rec) }
      end
    end

    desc 'solrvalidate <input> <output>' , 'Attempts to validate flattened Solr documents against schema'
    method_option   :schema_location,
                    default:  '/solr_schema.xml',
                    aliases:  '-s',
                    desc:  'Solr schema to load'
     method_option  :cull,
                    type: :boolean,
                    aliases: '-c',
                    desc: 'Writes valid records to output, warns about invalid records on STDERR'
    def solrvalidate(input = $stdin, output = $stdout)
      data_load_path = File.expand_path('../data', __dir__)
      schema_loc = File.join(data_load_path, 'solr_schema.xml')
      schema = Argot::SolrSchema.new(File.open(schema_loc))
      all_valid = true
      get_output(output) do |out|
        get_input(input) do |f|
          reader = Argot::Reader.new
          reader.process(f) do |data|
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
            end # data enumerate
          end # lambda
        end # input
      end # output
      exit(1) unless all_valid
    end

    ###############
    # Index into solr
    ###############
    desc 'ingest <input, default STDIN>', 'Flatten, suffix, and ingest an argot file'
    method_option   :solrUrl,
                    default:  "http://localhost:8983/solr/trln",
                    aliases:  '-s',
                    desc:  'Solr endpoint'
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
    method_option   :rules,
                    type:  :string,
                    default:  '',
                    aliases:  '-r',
                    desc:  'path to a rules file. Default is lib/data/rules.yml'
    method_option   :verbose,
                    type:  :boolean,
                    default:  false,
                    aliases:  '-v',
                    desc:  'display rules and error information'
    def ingest(input = nil)
      data_load_path = File.expand_path('../data', __dir__)

      config = YAML.load_file(data_load_path + options.config)
      fields = YAML.load_file(data_load_path + options.fields)
      flattener_config = YAML.load_file(data_load_path + options.flattener)
      results = []

      rules_file = options.rules.empty? ? [] : [options.rules]
      validator = Argot::Validator::from_files(rules_file)

      suffixer = Argot::Suffixer.new(config, fields)

      error_count = 0
      added_count = 0
      get_input(input) do |f|
        f.each_line do |line|
          doc = JSON.parse(line);
          valid = validator.valid?(doc)
          if valid.errors?
            error_count += 1
            # Show errors
            warn "Document #{doc['id']} skipped"
            if options.verbose
              valid.errors.each do |error|
                warn "#{error[:rule]}:"
                error[:errors].each do |e|
                  warn "\t  - #{e}"
                end
              end
              warn "\n"
            end # verbose
          else # we has_errors
            added_count += 1
            flattened = Argot::Flattener.process(doc, flattener_config)
            results << suffixer.process(flattened)
          end # has_errors
        end # each_line
      end # get_input

      unless results.empty?
        solr = RSolr.connect :url => options.solrUrl
        solr.add results
      end
      puts "Added #{added_count} document(s), skipped #{error_count} document(s)"
    end
  end
end
