require 'argot'
require 'thor'
require 'json'

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
        f = File.open("#{file}", "r")
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

  end
end