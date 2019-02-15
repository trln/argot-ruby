# frozen_string_literal: true

require 'argot/command_line'

describe Argot::CommandLine do
  subject { Argot::CommandLine.new }

  context 'get_input' do
    it('yields stdin when input is nil') do
      expect(subject.get_input).to be($stdin)
    end

    it("yields stdin when input is '-'") do
      expect(subject.get_input('-')).to be($stdin)
    end

    it('yields an IO object passed as an argument') do
      open_file('argot-allgood.json') do |f|
        expect(subject.get_input(f)).to be(f)
      end
    end
  end

  context 'flatten command' do
    it 'yields proper output for small test file' do
      open_file('argot-oneline.json') do |f|
        output = StringIO.new
        subject.flatten(f, output)
        expect(!output.string.empty?).to(be_truthy)
      end
    end
  end
end
