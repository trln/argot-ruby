module Util
  TEST_FILES = File.expand_path('../data', __FILE__)

  def self.find_file(name)
    path = File.join(Util::TEST_FILES, name)
    raise "Can't find #{name}" unless File.exist?(path)
    yield path if block_given?
    path
  end

  def self.get_file(name)
    file = File.open(find_file(name), 'r')
    if block_given?
      begin
        yield file
      ensure
        file.close
      end
    end
    file
  end

  def self.get_json(name)
    r = {}
    get_file(name) do |f|
      r = JSON.parse(f.read)
      yield r if block_given?
    end
    r
  end
end
