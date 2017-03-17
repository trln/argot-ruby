module Util
    TEST_FILES = File.expand_path("../data", __FILE__)

    def self.find_file(name) 
        path = File.join(Util::TEST_FILES, name)
        if not File.exist?(path)
            raise "Unable to find required test file #{name}"
        end
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
end

