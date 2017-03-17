require 'argot'
require 'thor'
require 'json'
require 'yaml'
require 'rsolr'

module Argot
  # The class that executes for the Argot command line utility.

  class CommandLine < Thor


    no_commands do 
      # Utility wrapper for producing a `:read` able object
      # based on a range of possible argument types.
      # @param input [`:read`, String]  if `nil`, or the string `-`, result is $stdin; if `:read`, result is the original argument,
      #  if a String other than `-`, result is an opened File handle.
      # @yield `:read`
      # @return `:read`
      def get_input(input=nil) 
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

      def get_output(output=nil)
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

    end

    ###############
    # Validate
    ###############
    desc "validate [INPUT]", "Validate Argot file converted from MARC (stdin or filename)."
    method_option   :rules,
                    :type => :string,
                    :default => "",
                    :aliases => "-r",
                    :desc => "path to a rules file. Default is lib/data/rules.yml"
    method_option   :verbose,
                    :type => :boolean,
                    :default => false,
                    :aliases => "-v",
                    :desc => "display rules and error information"

    def validate(input=nil)
      rules_file = options.rules.empty? ? [] : [options.rules]
      validator = Argot::Validator::from_files(rules_file)
      count = 0
      get_input(input) do |f|
        f.each_line do |line|
          doc = JSON.parse(line);
          valid = validator.is_valid?(doc)
          if valid.has_errors?
            count += 1
            puts "Document #{doc["id"]} will be skipped:"
            if options.verbose
              valid.errors.each do |error|
                puts "#{error[:rule]}:"
                error[:errors].each do |e|
                  puts "\t  - #{e}"
                end
              end # each error
              puts "\n"
            end # if verbose
          end
        end # each_line
       end #get_input
      puts "Found #{count} document(s) with errors"
    end

    ###############
    # Flatten
    ###############
    desc "flatten <input> <output>", "Flatten an argot file"
    method_option   :pretty,
                    :type => :boolean,
                    :default => false,
                    :aliases => "-p",
                    :desc => "pretty print resulting json"
    def flatten(input=$stdin, output=$stdout)
      results = []
      get_input(input) do |f|
        f.each_line do |line|
            doc = JSON.parse(line);
            results << Argot::Flattener.process(doc)
        end
      end
      if !results.empty?
        get_output(output) do |f|
          f.write options.pretty ? JSON.pretty_generate(results) : JSON.generate(results)
        end
      end
    end

    ###############
    # Suffix
    ###############
    desc "suffix <input, default stdin> <output, default stdout>", "Flatten and Suffix an argot file ("
    method_option   :pretty,
                    :type => :boolean,
                    :default => false,
                    :aliases => "-p",
                    :desc => "pretty print resulting json"
    method_option   :fields,
                    :default => "/solr_fields_config.yml",
                    :aliases => "-f",
                    :desc => "Solr fields configuration file"
    method_option   :config,
                    :default => "/solr_suffixer_config.yml",
                    :aliases => "-c",
                    :desc => "Solr suffixer config file"

    def suffix(input=$stdin, output=$stdout)
      data_load_path = File.expand_path("../data", File.dirname(__FILE__))
      config = YAML.load_file(data_load_path + options.config)
      fields = YAML.load_file(data_load_path + options.fields)
      results = []
      suffixer = Argot::Suffixer.new(config, fields)
      get_input(input) do |f|
        f.each_line do |line|
            doc = JSON.parse(line);
            flattened = Argot::Flattener.process(doc)
            results << suffixer.process(flattened)
        end
      end

      if !results.empty?
        get_output(output) do |f|        
            if options[:pretty] 
                f.puts JSON.pretty_generate(results)
            else 
                f.puts JSON.generate(results)
            end
        end
      end
    end

    ###############
    # Index into solr
    ###############
    desc "ingest <input, default STDIN>", "Flatten, suffix, and ingest an argot file"
    method_option   :solrUrl,
                    :default => "http://localhost:8983/solr/trln",
                    :aliases => "-s",
                    :desc => "Solr endpoint"
    method_option   :fields,
                    :default => "/solr_fields_config.yml",
                    :aliases => "-f",
                    :desc => "Solr fields configuration file"
    method_option   :config,
                    :default => "/solr_suffixer_config.yml",
                    :aliases => "-c",
                    :desc => "Solr suffixer config file"
    method_option   :rules,
                    :type => :string,
                    :default => "",
                    :aliases => "-r",
                    :desc => "path to a rules file. Default is lib/data/rules.yml"
    method_option   :verbose,
                    :type => :boolean,
                    :default => false,
                    :aliases => "-v",
                    :desc => "display rules and error information"

    def ingest(input=nil)
      data_load_path = File.expand_path("../data", File.dirname(__FILE__))
      
      config = YAML.load_file(data_load_path + options.config)
      fields = YAML.load_file(data_load_path + options.fields)
      results = []
      
      rules_file = options.rules.empty? ? [] : [options.rules]
      validator = Argot::Validator::from_files(rules_file)

      suffixer = Argot::Suffixer.new(config, fields)

      error_count = 0
      added_count = 0
      get_input(input) do |f|
        f.each_line do |line|
          doc = JSON.parse(line);
          valid = validator.is_valid?(doc)
          if valid.has_errors?
            error_count += 1
            # Show errors
            $stderr.puts "Document #{doc["id"]} skipped"
            if options.verbose
              valid.errors.each do |error|
              $stderr.puts "#{error[:rule]}:"
              error[:errors].each do |e|
                $stderr.puts "\t  - #{e}"
              end
            end
            $stderr.puts "\n"
          end
        else
          added_count += 1
          flattened = Argot::Flattener.process(doc)
          results << suffixer.process(flattened)
        end
      end

      if !results.empty?
        solr = RSolr.connect :url => options.solrUrl
        solr.add results
      end
      puts "Added #{added_count} document(s), skipped #{error_count} document(s)"
    end

  end
end