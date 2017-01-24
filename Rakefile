require 'bundler/gem_tasks'
require 'rake/testtask'

if RUBY_PLATFORM =~ /java/
    require 'jars/installer'
end

Rake::TestTask.new do |t|
        t.libs << 'test'
end

desc "Run tests"
task :default => :test
