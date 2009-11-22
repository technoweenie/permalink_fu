require 'rake'
require 'rake/testtask'
Rake::TestTask.new do |t|
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

desc 'Default: run test examples'
task :default => 'test'