require 'argot'
require 'thor'
require 'json'
require 'yaml'
require 'rsolr'

module Argot
  # The class that executes for the Argot command line utility.

  class CommandLine < Thor

    ###############
    # Flatten
    ###############
    desc "flatten <input> <output>", "Flatten an argot file"
    method_option   :pretty,
                    :type => :boolean,
                    :default => false,
                    :aliases => "-p",
                    :desc => "pretty print resulting json"

    def flatten(input, output)

      results = []
      
      if File.exist?(input)
        f = File.open("#{input}", "r")
        f.each_line do |line|
            doc = JSON.parse(line);
            results << Argot::Flattener.process(doc)
        end
      end

      if !results.empty?
        open("#{output}", "w") do |f|
          if options.pretty 
              f.puts JSON.pretty_generate(results)
          else 
              f.puts JSON.generate(results)
          end
        end
      end
    end

    ###############
    # Suffix
    ###############
    desc "suffix <input> <output>", "Flatten and Suffix an argot file"
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

    def suffix(input, output)

      data_load_path = File.expand_path("../data", File.dirname(__FILE__))
      
      config = YAML.load_file(data_load_path + options.config)
      fields = YAML.load_file(data_load_path + options.fields)
      results = []
      
      suffixer = Argot::Suffixer.new(config, fields)

      if File.exist?(input)        
        f = File.open("#{input}", "r")
        f.each_line do |line|
            doc = JSON.parse(line);
            flattened = Argot::Flattener.process(doc)
            results << suffixer.process(flattened)
        end
      end

      if !results.empty?
        open("#{output}", "w") do |f|
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
    desc "ingest <input>", "Flatten, suffix, and ingest an argot file"
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

    def ingest(input)

      data_load_path = File.expand_path("../data", File.dirname(__FILE__))
      
      config = YAML.load_file(data_load_path + options.config)
      fields = YAML.load_file(data_load_path + options.fields)
      results = []
      
      suffixer = Argot::Suffixer.new(config, fields)

      if File.exist?(input)        
        f = File.open("#{input}", "r")
        f.each_line do |line|
            doc = JSON.parse(line);
            flattened = Argot::Flattener.process(doc)
            results << suffixer.process(flattened)
        end
      end

      if !results.empty?
        solr = RSolr.connect :url => options.solrUrl
        solr.add results
      end
    end

  end
end