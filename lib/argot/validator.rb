require 'yaml' 
require 'ostruct'

module Argot

    ##
    # Struct representing the result of invoking a rule on a record.
    # * +name+ : the name (short description) of the rule
    # * +errors+ : an array of strings indicating errors with the record
    # * +warnings+ : an array of strings indicating problems with the record
    #   that will not result in its being rejected.
    RuleResult = Struct.new('RuleResult',:name,:errors,:warnings) do
        ##
        # creates a new empty instance 
        def self.empty(name) 
            RuleResult.new(name,[].freeze, [].freeze).freeze
        end
    end

    ##
    # Struct representing the result of invoking all of a Validator's rules
    # on a record.
    # * +location+ : the location of the error in the source.
    #   it is up to the caller to provide this and the consumer to
    #   interpret.
    # @param [Array<Hash>] :errors  :rule => rule.name, :errors => rule errors }+
    # * +warnings+ : an array of +{ :rule => rule.name, :warnings => rule.warnings }+
    ValidationResult = Struct.new(:location, :errors, :warnings) do
      def self.create(location = 0)
        ValidationResult.new(location, [], [])
      end

      ##
      # Checks whether any of the rules contained in this result reported
      # an error
      def errors?
        !errors.empty?
      end

      ##
      # Adds the result of an individual rule to this result.
      # * +result+ a :rdoc-ref RuleResult instance
      def <<(result)
        unless result.errors.empty?
          errors << { rule: result.name, errors: result.errors }
        end
        unless result.warnings.empty?
          warnings << { rule: result.name, warnings: result.warnings }
        end
        self
      end
    end

    ##
    # Basic implementation of a validator for JSON files in the 'argot'
    # format.  Allows loading of rules from YAML files in a default location
    # and adding rules generated programmatically.
    class Validator
      attr_accessor :rules

      attr_reader :rules_files

      ##
      # Creates a new instance from YAML files specified as arguments.
      # * +rules_files+ - an array of filenames to load rules from
      #   If no files are specified, loads rules from files named +rule\*.yml+
      #   this gem's data directory (+../../data+ relative to this file)
      # see BasicRule for examples.
      def self.from_files(rules_files = [])
        if rules_files.empty?
          data = File.expand_path('../../data', __FILE__)
          rules_files = Dir.glob(data + '/rule*.yml').collect do |f|
            File.new(f)
          end
        end
        @rules = rules_files.collect do |x|
          File.new(x)
        end
        Validator.new(compile(rules_files))
      end

      ##
      # Compiles an array of YAML rules files into executable rules
      # * +files+ : an array of File objects from which to load rules.
      #
      # return value is a list of executable rules.
      #
      # see BasicRule for documentation format
      def self.compile(files)
        rules = []
        files.each do |f|
          next unless f && File.exist?(f)
          ruledefs = YAML.safe_load(f)
          ruledefs.each do |rd|
            rules << BasicRule.new(rd)
          end
        end
        rules
      end

      ##
      # Creates a new validator with a supplied set of rules.
      # * +rules+ an array of callable rules.
      def initialize(rules)
        @rules = rules
      end

      ##
      # Adds a new rule on to the end of existing rules
      # Rule must be in the form of a 'callable' that returns
      # an object corresponding to the basic structure of
      # the RuleResult struct.
      def <<(rule)
        @rules = [] if @rules.nil?
        unless rule.method_defined?(:call)
          raise 'Rules added with << must respond to #call'
        end
        @rules << rule
      end

      ##
      # Tests whether a given record is valid, returning boolean +true+ if
      # the record is valid; if a block is supplied, the block will
      # be invoked with a collection of the errors and rules that were
      # violated for more detailed error reporting.
      #
      #
      # * +location+  the record or line number in the file being processed
      # see {ValidationResult}[rdoc-ref:Argot::ValidationResult]
      def valid?(rec, location = 0)
        results = ValidationResult.create(location)
        @rules.each do |r|
          begin
            result = r.call(rec)
          rescue StandardError => e
            result = RuleResult.new(r.data.name, [e.message], [e.backtrace.inspect])
          end
          results << result
        end
        yield results if block_given?
        results
      end
    end

    ##
    # Implementation of a rule that can be loaded from a data file.  Supported attributes:

    # * +name+ : (required) the name and short description of a rule.
    # * +path+ : (required) the path within an argot document to the field this rule handles
    #   e.g. +title.main+ refers to the +main+ attribute of the top-level +title+ attribute.
    # * +required+ : (optional, defaults to +false+) whether the field must be present in the document.
    # * +type+ : (optional) - the expected Ruby type of object at +path+, e.g. +String+ or +Fixnum+.
    # * +single+ : (optional, defaults to +false+) - there should only be 1 value
    #   this attribute is only used to check validity if the field is present.  If left
    #   unspecfied, no type checking will be done.
    #
    # === YAML
    # rules can be specified in a YAML file using the syntax:
    #  - name : 'Title' attribute must be present
    #    path : title
    #    required : true
    #  - name : 'local_id' attribute is required
    #    path : local_id
    #    required: true
    #    type : string
    # The above defines two rules, one of which checks for the existence of a 'title' attribute that
    # can have any value, and the other which verfies the presence of a +local_id+ attribute that is a 
    # ruby String (i.e. if local_id is itself an object, this rule would be violated)
    class BasicRule
      attr_reader :data

      ##
      # Creates a rule from a data structure.
      # * +rule_obj: a data structure that contains at least a
      # +name+ and +path+ attribute, as detailed above.
      def initialize(rule_obj)
        @data = OpenStruct.new(rule_obj)
        compile
      end

      ##
      # invokes the rule against the supplied record
      # * +rec+ : the Argot record to be validated
      # :returns: a RuleResult (or equivalent)
      # rubocop:disable MethodLength, LineLength
      def call(rec)
        result = RuleResult.new(@data.name, [], [])
        value = @expr.call(rec)
        result.errors << "#{@data.path} not found" if value.nil? && @data.required
        unless @data.type.nil?
          if @data.type.to_s != value.class.to_s
            result.errors << "#{@data.path} should be type #{@data.type} (found: #{value.class})"
          end
        end
        if value.is_a?(Array) && @data.single
          unless value[1].nil?
            result.errors << "#{@data.path} should only have a single value, multiple values found"
          end
        end
        result
      end

      private

      def empty_result
        RuleResult.new(@data.name, [].freeze, [].freeze)
      end

      def compile
        keys = @data.path.split('.')
        @expr = lambda do |hash|
          keys.inject(hash) do |obj, key|
            begin
              result = obj[key]
            rescue
              nil
            end
            result
          end
        end
      end
    end
end
