# frozen_string_literal: true

require 'fiber'
require 'logger'
unless Object.respond_to?(:itself)
  # add 'itself' method for Ruby pre-2.1.0
  class Object
    def itself
      self
    end
  end
end
module Argot
  # Base for a stage (step) in a data processing pipeline
  #
  # @attribute source [Stage] the stage preceding this one
  # @attribute name [String] the human friendly name for this stage.
  #
  # Typically you will not need to use or directly subclass this
  # class when constructing a pipeline
  #
  # Each instance of this class wraps a +Fiber+, and some of that
  # implementation detail leaks, e.g. the #resume method.
  #
  # Conceptually, each stage is responsible for asking its input to
  # yield the next value to be processed.  Once the stage has done
  # its processing, it will yield its value (and control) to the
  # next stage.  This allows each record to be sent through the pipeline
  # individually, reducing memory requirements.
  #
  # A stage's Fiber 'ends' once it receives (not *catches*!)
  # StopIteration at its input.
  class Stage
    attr_accessor :source, :name

    # intiializes this instance
    # @param [Hash] options options for this stage
    # @option options [String] name a name for this stage.
    def initialize(options = {})
      @transformer ||= method(:transform)
      @filter ||= method(:filter)
      @fiber_delegate = Fiber.new do
        process
      end
      options.each do |k, v|
        send "#{k}=", v if respond_to?("#{k}=".intern)
      end
    end

    # Chains the output of this stage to a subsequent stage
    # @param next_stage the next stage in processing
    def |(other)
      other.source = self
      other
    end

    # Resumes the Fiber underlying this instance, preparing
    # it to process the next record.
    def resume
      raise StopIteration unless @fiber_delegate.alive?
      @fiber_delegate.resume
    end

    def process
      while (value = input)
        handle_value(value)
      end
      StopIteration
    end

    # pull the next value from the previous stage
    def input
      source.resume
    end

    # send the result of this stage to the next stage
    # @param value the result generated by this stage.
    def output(value)
      Fiber.yield(value)
    end

    # Processes the current value and call #output
    # with the result unless the result should be filtered
    def handle_value(value)
      if value == StopIteration
        output(StopIteration)
      elsif @filter.call(value)
        output(@transformer.call(value))
      end
    end

    # performs the transformation of the input value
    # @param value the value provided to this stage
    # @return the transformed result.
    def transform(value)
      value
    end

    # Tests whether the value provided to this stage should be passed
    # on to the next stage
    # @param value [Object] the value to be processed
    # @return true if the value passes the filter, false if not.
    def filter(_value)
      true
    end

    def inspect
      "Stage(#{name})"
    end

    # Gets the stages from this one back to the first one in
    # the chain (in reverse order of execution!)
    def path
      @path ||= compute_path
    end

    # Method called by the parent pipeline when execution of the pipeline
    # is completed; allows stateful stages to de-allocate expensive resources,
    # close sockets or database connections, etc.   The default
    # implementation is a no-op.
    def finish; end    

    # Method called by a parent pipeline immediately before execution
    # of the pipeline; allows stateful stages to allocate expensive
    # resources at the point of need, check necessary conditions, etc.
    def start
      @fiber_delegate = Fiber.new do
        process
      end
    end

    private

    def compute_path
      result = [self]
      while (prev = result.last.source)
        result << prev
      end
      result
    end
  end

  # Base class for a stage that filters results without otherwise
  # processing them.
  # @param &block a block that returns true for results that should
  # be passed down the pipeline, and false for results that should not
  class Filter < Stage
    def initialize(options = {}, &block)
      options[:name] ||= 'filter'
      @filter = block
      super
    end
  end

  # Subclass of Filter that counts records seen and rejected
  # @param &block a block that returns tru for results that
  # should be passed along, and false for results that should not
  # @attr [Fixnum] :seen number of records this filter recieved on
  # its 'input port'
  # @attr [Fixnum] :filtered number of records this filter filtered
  # out.
  class CountingFilter < Stage
    attr_reader :seen, :filtered

    def initialize(options = {}, &block)
      super
      @filter = lambda do |x|
        @seen += 1
        res = block.yield(x)
        @filtered += 1 unless res
        yield res
      end
    end
  end

  # Base class for a stage that transforms results passed into it
  # @param &block a block whose return value will be passed to subsequent
  #        stages.
  class Transformer < Stage
    def initialize(options = {}, &block)
      options[:name] ||= 'transformer'
      @transformer = block
      super
    end
  end

    # "Transformer" that executes its supplied block on the input value,
    # while also passing the original value on to subsequent stages.  Primarily
    # useful for debugging
    class Peeker < Transformer
      IDENTITY = Proc.new(&:itself)
      def initialize(options={}, &block)
        options[:name] ||= 'peeker'
        @copy = options[:unsafe] || false
        super
        @handler = @transformer
        @transformer = IDENTITY
      end

      def handle_value(value)
        @handler.call(@copy ? Marshal.load(Marshal.dump(value)) : value) unless value == StopIteration
        super(value)
      end
    end

  # Allows premature termination of a pipeline the first time a condition
  # is not met (similar to Enumeration#take_while).
  class TakeWhile < Peeker
    def initialize(options = {}, &block)
      options[:name] ||= 'takewhile'
      super
    end

    def handle_value(value)
      result = @handler.call(value)
      if result
        super
      else
        super(StopIteration)
      end
    end
  end

  # Stage that groups individual items on its input to
  # Enumerations of at most a certain size on its output.
  # One use for this is as a stage immediately before a
  # processing stage that works works most efficiently
  # on 'chunks' of data.
  # @yield [Enumerator]
  #
  # The internal collection buffer is yielded to the following stages
  # as a lazy Enumerator; if you really want an array, you'll
  # need to call #to_a on the result.
  class Gatherer < Stage
    attr_accessor :size

    # Create a new instance
    # @param size [Int] the maximum number of records to
    #    store in an array before invoking the next stage.
    def initialize(size, options = {})
      @size = size
      @buffer = []
      options[:name] ||= "gatherer(#{size})"
      @transformer = ->(x) { x }
      super(options)
    end

    def handle_value(value)
      if value == StopIteration
        output(@buffer.each)
        output([StopIteration].each)
      else
        @buffer << value
        if @buffer.length == @size
          output(@buffer.each)
          @buffer = []
        end
      end
    end
  end

  # Stage that converts arrays on its input to individual members
  # on its output.  One use is to turn the results of a bulk data
  # processing 'gather' step back into individual records.
  # @see Gatherer
  class Scatterer < Stage
    def initialize(options={})
      options[:name] ||= 'scatterer'
      super
    end

    def handle_value(value)
      value.each { |v| output(v) }
    end
  end

  # Stage that gathers its input to an array.  Use with caution!
  class Arrayifier < Transformer
    def initialize(options = {})
      options[:name] ||= 'to_array'
      super
    end

    def handle_value(value)
      result = value.to_a.take_while { |y| y != StopIteration }
      result.empty? ? StopIteration : result
    end
  end

  # Implements the compact DSL for pipeline construction.
  # The primary use for this class is to provide standardized constructors
  # for pipeline stages, which is used as the basis for a DSL for
  # pipeline construction.
  #
  # The fundamental job of this class is to evaluate a block and
  # populate the `stages` attribute, which will be wired together
  # into a pipeline by Pipeline#setup
  # All stage definitions accept an options hash, and the +name+
  # option allows explicity setting the name of the stage (helpful
  # for debugging/tracking down where errors occur).  Many stage
  # definitions accept a block as well
  class Builder
    # the stages, in the original order
    attr_reader :stages
    def initialize
      @stages = []
    end

    # define a filter stage given a block (and any options)
    # @see Filter
    def filter(options = {}, &block)
      check_options('filter', options)
      @stages << Filter.new(options,&block)
    end

    # define a transformer stage given a block
    # (and any options)
    # @see Transformer
    def transform(options = {}, &block)
      check_options('transformer', options)
      @stages << Transformer.new(options,&block)
    end

    # define a gatherer stage, which collects input records into
    # groupings of maximum size +size+ before passing them onto
    # the next stage
    # @see Gatherer
    def gather(size, options = {})
      @stages << Gatherer.new(size,options)
    end

    # converts an enumerator (output of a Gatherer) to an array.
    def to_array
      transform(name: 'to_array') do |x|
        result = x.to_a.take_while { |y| y != StopIteration }
        result.empty? ? StopIteration : result
      end
    end

    # defines a 'scatter' stage, which converts the output of a
    # gatherer back into single records.
    def scatter(options = {})
      @stages << Scatterer.new(options)
    end

    # defines a stage that will terminate processing once its condition
    # is not met.  Note if the condition evaluates to +false+, processing
    # is terminated immediately (subsequent stages in the pipeline will not be
    # executed)
    def take_while(options = {}, &block)
      @stages << TakeWhile.new(options,&block)
    end

    # defines a stage that provides access to the output of a previous stage.
    # The supplied block will be executed for each record.
    # In normal use, the block should take care to *not* modify the
    # input value, because doing so may alter the value in unexpected ways.
    # @param options [Hash] options control the handling of the value
    # @option options [Boolean] unsafe set to true if the supplied
    # value might be altered within +&block+ (provides a defensive
    # deep copy instead of the original value -- computationally expensive,
    # so avoid mutation of values!)
    def peek(options = {}, &block)
      @stages << Peeker.new(options, &block)
    end

    # defines a filter that rejects nil values
    def nonnil
      filter(name: 'Filter blanks') { |x| !x.nil? }
    end

    # @return the result of calling #upcase on input strings
    def upcase
      transform(name: 'Upper case') &:upcase
    end

    private

    # ensures that options are reasonable, e.g. adding
    # a name for the stage if one was not supplied.
    def check_options(type, options = {})
      options[:name] ||= "#{type}-#{@stages.length + 1}"
    end
  end

  # A processing chain composed of multiple independent stages.
  # Objects fed into the pipeline (via #run(Enumerable) )
  # are sent through its stages and +yield+ed to the block
  #
  # Pipelines can simplify construrction of complex chains
  # of processing logic over large record sets by allowing each
  # component to be treated separately.
  # While it is possible
  # to achieve similar effects by chaining Enumerators, doing so has
  # two drawbacks: first, it requires loading all of the intermediate
  # collections created by each processing step into memory, and second,
  # it complicates the logic for error handling -- an error during
  # any step of the chain breaks the entire chain.
  # A pipeline works by sending each element in the original enumeration
  # through a series of stages one at a time, until it emerges on
  # the end of the pipeline for whatever final processing is needed.
  # Thus, the memory requirement can be kept to a minimum.  This also
  # allows the pipeline to recover from any StandardError thrown during
  # the processing of that one record.
  #
  # Normal stages in a pipeline can either transform their inputs, or
  # filter them.  Specialty stages exist to gather steps into groups,
  # split groups back into individual records, peek at intermediate
  # results.
  #
  # Pipelines can be constructed in one of two ways, one inspired
  # by the command line and one using a Domain Specific Language (DSL).448
  #
  # UNIX pipe-inspired:
  #
  # # reject all nil values
  #   nil_filter = Filter.new( {|x| not x.nil? })
  #   downcase_transformer = Transformer.new({ |x| x.downcase })
  #   words = [ 'thiS', nil, 'IS', 'THE', 'sTory', nil, 'oF', 'tRLn' ]
  #
  #   p = Pipeline.new | nil_filter | downcase_transformer
  #   p.run(words) { |x| puts x }
  #   # prints "this is the story  of trln" one word per line
  #
  # Alternately, use the DSL; this should be more approachable than the
  # above, and provides some syntactic niceties:
  #
  #   p = Pipeline.setup {
  #       nonnil
  #       upcase
  #   }
  #
  #   p.run(words) { |x| puts x }
  #   # same output as above, but upper-cased
  #
  # In this first DSL example, `nonnil` and `upcase` are short names for a
  # "non-nil" Filter and upper-casing Transformer.  More generic mnemonics
  # are also available to allow you to supply your own filter/transformer
  # blocks, so the following is (nearly) equivalent:
  #
  #   p = Pipeline.setup {
  #       filter { |x| not x.nil? }
  #       transform { |x| x.upcase }
  #   }
  #   # the difference from the named stage example is that the stages
  #     will have different names, but this only matters when you want to
  #     view the pipeline.
  #
  #   # as above ...
  #
  # "Named" filters and transformers are defined in the Builder class.
  # @see Builder for a complete set of available stage definitions.
  #
  # @todo more serious examples, perhaps involving stateful stages
  # @todo come up with an elegant way of adding new named stages
  #       for the DSL.
  #
  # Implementation inspired by UNIX pipes and, more directly,
  #
  # by Dave Thomas' series
  # https://pragdave.me/blog/2007/12/30/pipelines-using-fibers-in-ruby-19/
  # https://pragdave.me/blog/2008/01/01/pipelines-using-fibers-in-ruby-19part-ii/
  class Pipeline
    attr_reader :enumerable
    def initialize(options = {})
      @last_stage = self
      @logger = options[:logger] || Logger.new($stderr)
      @error = options[:error_handler]
      @rec = nil
    end

    # Adds a new stage to the end of the pipeline
    def |(other)
      if @last_stage != self
        @last_stage | other
      else
        other.source = self
      end
      @last_stage = other
      self
    end

    # sets the enumerable this pipeline pulls records from.
    def enumerable=(something)
      @enumerable = something.respond_to?(:next) ? something : something.each.lazy
      @delegate_fiber = Fiber.new do
        begin
          @enumerable.each do |val|
            @rec = val
            Fiber.yield val
          end
          Fiber.yield StopIteration
        rescue StopIteration => e
          @logger.warn("Uncaught StopIteration during pipeline execution : #{e}")
        end
      end
      something
    end

    def resume
      @delegate_fiber.resume
    end

    def name
      '(start)'
    end

    def source
      nil
    end

    def stages
      path.reverse
    end

    def path
      @last_stage.path
    end

    # displays the pipeline
    def debug
      '(input) ->' << stages.collect(&:name).join(' -> ') << ' -> (output)'
    end

    def start; end

    def finish; end

    def start_run
      stages.each do |stage|
        stage.start if stage.respond_to?(:start)
      end
    end

    def end_run
      stages.each do |stage|
        begin
          stage.finish if stage.respond_to?(:finish)
        rescue StandardError => e
          $stderr.write("Error calling finish on stage '#{stage.name} : #{e}\n")
        end
      end
      self
    end

    # Executes the pipeline, processing each end result with
    # a supplied block
    # @param source [#each] source of records for the pipeline.
    # @yield [Object, nil] the result of the final stage of the pipeline.
    def run(source)
      self.enumerable = source
      start_run
      loop do
        begin
          x = @last_stage.resume
          break if x == StopIteration
          yield x
        rescue StopIteration
          @logger.debug('received termination signal')
          break
        rescue StandardError => e
          if @error
            @error.call(@rec, e)
          else
            @logger.warn("Error processing #{@rec} : #{e}\n#{e.backtrace}")
          end
        end
      end
      end_run
    end

    # Build a pipeline using the DSL.
    # @param options [Hash] configuration for the Builder used to
    # create the pipeline.
    # @option options [Builder] :builder a Builder instance to use.  Defaults
    #   to Builder.new
    # @option options [Logger] :logger the error logger to be used in
    # the resulting Pipeline.
    # @yield [Pipeline] the pipeline definition
    def self.setup(options = {}, &block)
      builder = options[:builder] || Builder.new
      builder.instance_eval(&block)
      result = Pipeline.new(options)
      builder.stages.each { |stage| result | stage }
      result
    end
  end
end
