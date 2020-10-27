require 'bundler'
Bundler.setup

require 'rake'
require 'fileutils'
require 'openstudio'
require 'parallel'

#task default: 'tbd'

# throw way the run directory and everything in it.
def clear_run
  puts 'Deleting run diretory and underlying contents'

  # remove run directory
  FileUtils.rm_rf('run')
end

desc 'Delete contents under run directory'
task :clear_run do
  clear_run
end

# saving base path to measure gems to make it easier to maintain if it changes
def bundle_base_gem_path
  return '.bundle/install/ruby/2.5.0/bundler/gems'
end

# print out measure gems that are were installed by bundle
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

  return bundle_measure_paths.sort
end

desc 'Find Bundle measure paths to add to bundle osws'
task :find_bundle_measure_paths do
  find_bundle_measure_paths
end

# copy osw to run directory make changes to file and measure paths, and copy measure to short path if requested
def setup_osw(workflow_name,short_measure_path = false)
  puts "Adding copy in run/workflows directory of #{workflow_name} in workflow directory with updated measure paths set to use .bundle measure gems."

  # convert string to bool
  if short_measure_path == 'true' then short_measure_path = true end
  if short_measure_path == 'false' then short_measure_path = false end

  # make directory if does not exist
  FileUtils.mkdir_p("run/workflows/#{workflow_name}")

  # load OSW file
  osw = OpenStudio::WorkflowJSON.load("workflows/#{workflow_name}/in.osw").get
  runner = OpenStudio::Measure::OSRunner.new(osw)
  workflow = runner.workflow

  # saving osw early so I use findMeasure to copy to short path
  osw_path = "run/workflows/#{workflow_name}/in.osw"
  workflow.saveAs(osw_path)

  # replace measure paths, add in measure gem paths and measures from this repo
  puts "updating measure_paths to use the bundle measure gems"
  workflow.resetMeasurePaths
  find_bundle_measure_paths.each do |path|
    workflow.addMeasurePath("../../../#{path}")
  end
  # this is for measure at top level of repo
  workflow.addMeasurePath("../../../measures")

  # this is to try to avoid long file path issue on windows
  if short_measure_path

    # make short path if it doesn't exist
    puts "Copying measures in #{workflow_name} to run/measures directory."
    short_path = "run/measures"
      FileUtils.mkdir_p(short_path)

    # find path in gem to measures used in osw and copy them to short path
    workflow.workflowSteps.each do |step|
      if step.to_MeasureStep.is_initialized
        measure_step = step.to_MeasureStep.get
        measure_dir_name = measure_step.measureDirName
        source_path = workflow.findMeasure(measure_dir_name.to_s).get.to_s
        FileUtils.copy_entry(source_path, "#{short_path}/#{measure_dir_name}")
      end
    end

    # replace measure paths, add in measure gem paths and measures from this repo
    puts "updating measure_path to use the short measure path, measure will be copied to new location"
    workflow.resetMeasurePaths
    workflow.addMeasurePath("../../measures")
    # path to measures in this repo
    workflow.addMeasurePath("../../../measures") # add aback because lost when reset paths
  end

  # update other paths in the osw for new location (file_paths should be one level deeper)
  puts "updating file_paths to adjust for location of copied osw file."
  workflow.resetFilePaths
  # storing workflow.filePaths and then looping through them creates lots of extras, hard coded for now
  workflow.addFilePath("../../../weather")
  workflow.addFilePath("../../../seeds")
  workflow.addFilePath("../../../files")

  # generally should not need to use paths in measure arguments if use findFile within the measure
  # If this is not followed moving osws files for setup may break measure arguments that include paths.

  # save workflow
  puts "saving modified workflow"
  workflow.save

  return workflow
end

desc 'Setup single osw file to use bundler gems for measure paths'
task :setup_osw , [:workflow_name, :short_measures] do |task, args|
  args.with_defaults(workflow_name: 'bar_typical')
  args.with_defaults(short_measures: false)
  workflow_name = args[:workflow_name]
  # converting string to bool
  short_measures = args[:short_measures]
  if short_measures == 'true' then short_measures = true end
  if short_measures == 'false' then short_measures = false end
  setup_osw(workflow_name,short_measures) # leave bool for short measure false unless issues with long path on windows
end

desc 'Setup all osw files to use bundler gems for measure paths'
task :setup_all_osws , [:short_measures] do |task, args|
  args.with_defaults(short_measures: false)
  # convert string to bool
  short_measures = args[:short_measures]
  if short_measures == 'true' then short_measures = true end
  if short_measures == 'false' then short_measures = false end
  find_osws.each do |workflow_name|
    setup_osw(workflow_name,short_measures)
  end
end

# quick way to list osw files under the workflow directory for use in rake task used for setup_all_ows
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

# quick way to see which osw files are in the run/workflows directory. Used for run_osws
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

# just takes single osw and turns it into array to pass into run_osws
def run_osw(workflow_name, measures_only = false)
  run_osws([workflow_name],measures_only)
end

# this runs an array of osws. Bool is to run full simulation or measures only
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
  args.with_defaults(measures_only: false)
  # convert string to bool
  measures_only = args[:measures_only]
  if  measures_only == 'true' then measures_only = true end
  if  measures_only == 'false' then measures_only = false end
  run_osw(args[:workflow_name], measures_only)
end

desc 'Run all osws'
task :run_all_osws , [:measures_only] do |task, args|
  args.with_defaults(measures_only: false)
  measures_only = args[:measures_only]
  puts "Running all osws"
  run_osws(find_osws,measures_only)
end

desc 'setup additional measures that are not measure gems as if they were installed with bundle install'
task :setup_non_gem_measures do
  puts "Extending bundler install with measures collections that are not currently setup as a ruby gem. This requires SVN"
  puts "setup_osw tasks should be run after this method, or OSW files won't have access to these measures"

  # gather additional measures
  additional_measures = {}
  additional_measures['build_stock_resources'] = "https://github.com/NREL/OpenStudio-BuildStock/branches/multifamily-zedg/resources/measures"
  additional_measures['build_stock'] = "https://github.com/NREL/OpenStudio-BuildStock/branches/multifamily-zedg/measures"
  # either because this is a master or I'm checking out the entire repo I seem to need to pass in a revision as well.
  additional_measures['unmet_hours'] = "-r 99999  https://github.com/UnmetHours/openstudio-measures/branches/master"

  # setup additional measures
  additional_measures.each do |new_dir_name,measure_string|

    non_gem_measures = "#{bundle_base_gem_path}/#{new_dir_name}/lib/measures"
    FileUtils.mkdir_p(non_gem_measures)

    # add measures
    system("svn checkout #{measure_string} #{non_gem_measures}")
  end


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