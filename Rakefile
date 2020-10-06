require 'bundler'
Bundler.setup

require 'rake'
require 'fileutils'
require 'openstudio'

#task default: 'tbd'

desc 'Delete contents under run directory'
task :clear_run do

  puts 'Deleting run diretory and underlying contents'

  # remove run directory
  FileUtils.rm_rf('run')

end

desc 'Find Bundle measure paths to add to bundle osws'
task :find_bundle_measure_paths do

  bundle_base_gem_path = '.bundle/install/ruby/2.5.0/bundler/gems'
  bundle_measure_paths = []

  puts "Getting measure directories for bundle installed measure gems"
  gems = Dir.entries(bundle_base_gem_path)
  gems.each do |gem|
    # check if has lib/measures
    gem = "#{bundle_base_gem_path}/#{gem}/lib/measures"
    next if ! Dir.exists?(gem)
    bundle_measure_paths << gem
  end

  puts "found #{bundle_measure_paths.size} measure directories"
  puts "bundle_measure_paths:#{bundle_measure_paths.inspect}"

  bundle_measure_paths

end

desc 'Setup single osw file to use bundler gems for measure paths'
task :setup_osw , [:var] do |task, args|

  args.with_defaults(var: 'bar_typical')
  workflow_name = args.var.inspect.delete('"')
  puts "Adding copy in run/workflows directory of #{workflow_name} in workflow directory with updated measure paths set to use .bundle measure gems."

  # get measure paths (seems like method below is calling the task twice)
  bundle_measure_paths = Rake::Task["find_bundle_measure_paths"].execute.first.call

  # confirm directory exists
  Dir.mkdir("run") unless File.exists?("run")
  Dir.mkdir("run/workflows") unless File.exists?("run/workflows")
  Dir.mkdir("run/workflows/#{workflow_name}") unless File.exists?("run/workflows/#{workflow_name}")

  # load OSW file
  osw = OpenStudio::WorkflowJSON.load("workflows/#{workflow_name}/in.osw").get
  runner = OpenStudio::Measure::OSRunner.new(osw)
  workflow = runner.workflow

  # replace measure paths, add in measure gem paths and measures from this repo
  puts "updating measure_paths to use the bundle measure gems"
  workflow.resetMeasurePaths
  bundle_measure_paths.each do |path|
    workflow.addMeasurePath("../../../#{path}")
  end

  # path to measures in this repo
  workflow.addMeasurePath("../../../measures")

  # update other paths in the osw for new location (file_paths should be one level deeper)
  puts "updating file_paths to adjust for location of copied osw file."
  workflow.resetFilePaths
  # storing workflow.filePaths and then looping through them creates lots of extras, hard coded for now
  workflow.addFilePath("../../../weather")
  workflow.addFilePath("../../../seeds")
  workflow.addFilePath("../../../files")

  # generally should not need to use paths in measure arguments if use findFile within the measure

  # save workflow
  puts "saving modified workflow"
  osw_path = "run/workflows/#{workflow_name}/in.osw"
  workflow.saveAs(osw_path)

end

desc 'Run single osw'
task :run_osw , [:var] do |task, args|

  args.with_defaults(var: 'bar_typical')
  workflow_path = "run/workflows/#{args.var.inspect.delete('"')}/in.osw"
  puts "Running #{workflow_path}"
  system("openstudio run -w #{workflow_path}")
end

# todo - put as second arg in run_osw
desc 'Run single osw measures only'
task :run_osw_measures_only , [:var] do |task, args|

  args.with_defaults(var: 'bar_typical')
  workflow_path = "run/workflows/#{args.var.inspect.delete('"')}/in.osw"
  puts "Running #{workflow_path}"
  system("openstudio run -m -w #{workflow_path}")
end

# todo - add task that does setup and run in single step
desc 'Setup and run single osw'
task :setup_run_osw , [:var] do |task, args|

  args.with_defaults(var: 'bar_typical')
  arg = args.var.inspect.delete('"')

  bundle_measure_paths = Rake::Task["setup_osw"].execute
  bundle_measure_paths = Rake::Task["run_osw"].execute

end

# todo - add task that does setup run for all OSW files using parallel to run