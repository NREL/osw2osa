require 'bundler'
Bundler.setup

require 'rake'
require 'fileutils'
require 'openstudio'
require 'parallel'

#task default: 'tbd'

def clear_run
  puts 'Deleting run diretory and underlying contents'

  # remove run directory
  FileUtils.rm_rf('run')
end

desc 'Delete contents under run directory'
task :clear_run do
  clear_run
end

def bundle_base_gem_path
  return '.bundle/install/ruby/2.5.0/bundler/gems'
end

def find_bundle_measure_paths
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

  return bundle_measure_paths
end

desc 'Find Bundle measure paths to add to bundle osws'
task :find_bundle_measure_paths do
  find_bundle_measure_paths
end

def setup_osw(workflow_name,short_measure_path = false)
  puts "Adding copy in run/workflows directory of #{workflow_name} in workflow directory with updated measure paths set to use .bundle measure gems."

  # make directory if does not exist
  FileUtils.mkdir_p("run/workflows/#{workflow_name}")

  # load OSW file
  osw = OpenStudio::WorkflowJSON.load("workflows/#{workflow_name}/in.osw").get
  runner = OpenStudio::Measure::OSRunner.new(osw)
  workflow = runner.workflow

  workflow.resetMeasurePaths
  if ! short_measure_path
    # replace measure paths, add in measure gem paths and measures from this repo
    puts "updating measure_paths to use the bundle measure gems"
    workflow.resetMeasurePaths
    find_bundle_measure_paths.each do |path|
      workflow.addMeasurePath("../../../#{path}")
    end
  else
    # this is to try to avoid long file path issue on windows
    # copy measures to new location (always copy even if there because they may be outdated)
    puts "copying all bundle measure to run directory to shorten path"
    short_path = "run/measures"
    FileUtils.mkdir_p(short_path)
    find_bundle_measure_paths.each do |path|
      FileUtils.copy_entry(path, short_path)
    end

    # replace measure paths, add in measure gem paths and measures from this repo
    puts "updating measure_path to use the short measure path, measure will be copied to new location"
    workflow.addMeasurePath("../../measures")
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

  return workflow
end

desc 'Setup single osw file to use bundler gems for measure paths'
task :setup_osw , [:workflow_name, :short_measures] do |task, args|
  args.with_defaults(workflow_name: 'bar_typical')
  args.with_defaults(short_measures: 'false')
  workflow_name = args[:workflow_name]
  short_measures = args[:short_measures]
  setup_osw(workflow_name,short_measures) # leave bool for short measure false unless issues with long path on windows
end

desc 'Setup all osw files to use bundler gems for measure paths'
task :setup_all_osws do
  find_osws.each do |workflow_name|
    # todo - to update this to support short paths need to not copy measure for each osw
    setup_osw(workflow_name)
  end
end

def find_osws
  puts "Get names of workflows in workflows directory"
  workflow_names = []
  workflows = Dir.entries('workflows')
  workflows.each do |workflow|
    # check if has lib/measures
    workflow_path = "workflows/#{workflow}/in.osw"
    next if ! File.exists?(workflow_path)
    workflow_names << workflow
  end
  puts workflow_names

  return workflow_names
end

def find_setup_osws
  puts "Get names of workflows in run/workflows directory"
  workflow_names = []
  # make directory if does not exist
  FileUtils.mkdir_p('run/workflows')
  workflows = Dir.entries('run/workflows')
  workflows.each do |workflow|
    # check if has lib/measures
    workflow_path = "run/workflows/#{workflow}/in.osw"
    next if ! File.exists?(workflow_path)
    workflow_names << workflow
  end
  puts workflow_names

  return workflow_names
end

desc 'List OSW files in the measures workflows directory'
task :find_osws do
  find_osws
end

# just takes single osw and turns it into array
def run_osw(workflow_name, measures_only = false)
  run_osws([workflow_name],measures_only)
end

def run_osws(workflow_names, measures_only = false)
  jobs = []
  workflow_names.each do |workflow_name|

    # setup osw if it insn't already (don't always run setup to maintain changes in run/workflows user may have made for testing)
    if ! find_setup_osws.include?(workflow_name)
      puts "did not find #{workflow_name} setup in run/workflow directory, running setup_osw."
      setup_osw(workflow_name)
    end

    puts "Running #{workflow_name}"
    if measures_only
      jobs << "openstudio run -m -w run/workflows/#{workflow_name}/in.osw"
    else
      jobs << "openstudio run -w run/workflows/#{workflow_name}/in.osw"
    end
  end

  # run simulations
  num_parallel = 12 # can it default or input something like n-1
  Parallel.each(jobs, in_threads: num_parallel) do |job|
    puts job
    system(job)
  end

end

desc 'Run single osw'
task :run_osw , [:workflow_name, :measures_only] do |task, args|
  args.with_defaults(workflow_name: 'bar_typical')
  args.with_defaults(measures_only: 'false')
  run_osw(args[:workflow_name], args[:measures_only])
end

desc 'Run all osws'
task :run_all_osws do
  puts "Running all osws"
  run_osws(find_osws)
end

desc 'Setup and run single osw'
task :setup_run_osw , [:workflow_name] do |task, args|
  args.with_defaults(workflow_name: 'bar_typical')
  workflow_name = args.workflow_name.inspect.delete('"')
  setup_osw(workflow_name)
  run_osw(workflow_name)
end

# ARGV[0] json file is generated unless false
# ARGV[1] zip file is generated unless false
# ARGV[2] variable set name
# ARGV[3] parent directory name for source osw (can also be picked based on analysis name in ARGV[3])
# ARG[4] file name for template osa
desc 'Setup an analysis including zip file and OSA (can run with all defaults'
task :setup_osa , [:json_bool, :zip_bool, :var_set, :select_osw, :select_osa] do |task, args|

  # setup osw if it insn't already
  if ! args[:select_osw].nil? && ! find_setup_osws.include?(args[:select_osw])
    puts "did not find #{args[:select_osw]} setup in run/workflow directory, running setup_osw."
    setup_osw(args[:select_osw])
  end

  # osw_2_osa.rb has defaults so they are not needed here.

  puts "Inspecting Rake task arguments"
  puts "json file is generated: #{args[:json_bool]}"
  puts "zip file is generated: #{args[:zip_bool]}"
  puts "variable set name: #{args[:var_set]}"
  puts "source osw_name: #{args[:select_osw]}"
  puts "template osa name: #{args[:select_osa]}"
  puts "calling osw_2_osa.rb"
  puts "--------------"
  system("ruby osw_2_osa.rb #{args[:json_bool]} #{args[:zip_bool]} #{args[:var_set]} #{args[:select_osw]} #{args[:select_osa]}")
end

# todo - create task to meta CLI (there is more setup for computer for this to work provide good instructions)