require 'bundler'
Bundler.setup

require 'rake'
require 'fileutils'
require 'openstudio'
require 'parallel'
require 'open3' 
require 'json' 
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
  return '.bundle/install/ruby/3.2.0/bundler/gems'
end

def bundle_base_gem_path_release
  return '.bundle/install/ruby/3.2.0/gems'
end

# print out measure gems that are were installed by bundle
def find_bundle_measure_paths
  bundle_measure_paths = []

  puts "Getting measure directories for bundle installed measure gems"
  # check for gems from GitHub.com branches
  if File.directory?(bundle_base_gem_path)
    gems = Dir.entries(bundle_base_gem_path)
    gems.each do |gem|
      # check if has lib/measures
      gem = "#{bundle_base_gem_path}/#{gem}/lib/measures"
      next if ! Dir.exist?(gem)
      next if gem.include?('openstudio-extension') # never want to include measure fromhere
      bundle_measure_paths << gem
    end
  end

  # check for gems from GitHub.com branches
  if File.directory?(bundle_base_gem_path_release)
    gems = Dir.entries(bundle_base_gem_path_release)
    gems.each do |gem|
      # check if has lib/measures
      gem = "#{bundle_base_gem_path_release}/#{gem}/lib/measures"
      next if ! Dir.exist?(gem)
      next if gem.include?('openstudio-extension') # never want to include measure fromhere
      bundle_measure_paths << gem
    end
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
    next if ! File.exist?(workflow_path)
    workflow_names << workflow
  end
  puts workflow_names

  return workflow_names
end

# quick way to see which osw files are in the run/workflows directory. Used for run_osws
def find_setup_osws
  #puts "Get names of workflows in run/workflows directory"
  workflow_names = []
  # make directory if does not exist
  FileUtils.mkdir_p('run/workflows')
  workflows = Dir.entries('run/workflows')
  workflows.each do |workflow|
    # check if has lib/measures
    workflow_path = "run/workflows/#{workflow}/in.osw"
    next if ! File.exist?(workflow_path)
    workflow_names << workflow
  end
  #puts workflow_names

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

    if measures_only
      #jobs << "openstudio run -m -w run/workflows/#{workflow_name}/in.osw"

      # alternate version of cli call to  load urbanop-geojson gem. Adjust for specific install path
      jobs << "openstudio -l Trace -I /Users/dgoldwas/Documents/github/nrel/osw2osa/.bundle/install/ruby/3.2.0/bundler/gems/urbanopt-geojson-gem-a3a434b21353/lib -I /Users/dgoldwas/Documents/github/nrel/osw2osa/.bundle/install/ruby/3.2.0/bundler/gems/urbanopt-core-gem-2bd8985fab24/lib run -m -w run/workflows/#{workflow_name}/in.osw"

    else
      #jobs << "openstudio run -w run/workflows/#{workflow_name}/in.osw"

      # alternate version of cli call to  load urbanop-geojson gem. Adjust for specific install path

      # with custom standards
      #jobs << "openstudio -l Trace -I /Users/dgoldwas/.rbenv/versions/3.2.2/lib/ruby/gems/3.2.0/gems/openstudio-standards-0.6.3/lib -I /Users/dgoldwas/Documents/github/nrel/osw2osa/.bundle/install/ruby/3.2.0/bundler/gems/urbanopt-geojson-gem-a3a434b21353/lib -I /Users/dgoldwas/Documents/github/nrel/osw2osa/.bundle/install/ruby/3.2.0/bundler/gems/urbanopt-core-gem-2bd8985fab24/lib run -w run/workflows/#{workflow_name}/in.osw"
      
      # without custom standards
      jobs << "openstudio -l Trace -I /Users/dgoldwas/Documents/github/nrel/osw2osa/.bundle/install/ruby/3.2.0/bundler/gems/urbanopt-geojson-gem-a3a434b21353/lib -I /Users/dgoldwas/Documents/github/nrel/osw2osa/.bundle/install/ruby/3.2.0/bundler/gems/urbanopt-core-gem-2bd8985fab24/lib run -w run/workflows/#{workflow_name}/in.osw"
      
      # approach using bundler instead of include isn't working yet, but I'll try to get it working
      #jobs << "openstudio -l Trace --bundle /Users/dgoldwas/Documents/github/nrel/osw2osa/Gemfile --bundle_path /Users/dgoldwas/Documents/github/nrel/osw2osa/.bundle/install run -w run/workflows/#{workflow_name}/in.osw"

    end
  end

  # run simulations
  # determine available processors on running host
  workflows_passed = true
  num_parallel = (Parallel.processor_count - 1).floor
  puts "Running workflows in parallel on #{num_parallel} processors"
  Parallel.each(jobs, in_threads: num_parallel) do |job|
    puts "Running #{job}"
    stdout, stderr, status = Open3.capture3(job)
    unless status.success?
      # wait_thr causing issues again
      # puts "#{job}: returned Error: #{wait_thr.value.exitstatus}"
      puts "stdout: #{stdout}"
      puts "stderr: #{stderr}"
      workflows_passed = false
    end
  end
  unless workflows_passed
    raise "A workflow failed. Please check logs for further info" 
  end  

  # Check the result codes in the workflow output out.osw json file 
  # and raise error if any equal Fail
  workflows_passed = true
  workflow_names.each do |workflow_name|
    # Check for file existence
    unless File.exist?("run/workflows/#{workflow_name}/out.osw")
      raise "File run/workflows/#{workflow_name}/out.osw not found"
    end
    # check status code in json output
    unless check_status_code?("run/workflows/#{workflow_name}/out.osw")
      puts "Workflow #{workflow_name} Failed"
      workflows_passed = false
    end 
  end
  # Check if any workflow failed
  unless workflows_passed
    raise "A workflow failed. Please check logs for further info" 
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

# Parse json and check status code
def check_status_code?(workflow_outfile)
  osw = JSON.parse(File.read(workflow_outfile))
  if osw["completed_status"] == "Success"
    return true
  else
    return false
  end
end

# setup OSW to be run by OS Application (made to have way to run wihtout using CLI in command line)
def setup_os_app(workflow_name)
  puts "Setting up OSM that can be used to run this OSW through the OpenStudio Application."

  if ! find_setup_osws.include?(workflow_name)
    puts "did not find #{workflow_name} setup in run/workflow directory, running setup_osw."
    setup_osw(workflow_name)
  end

  # load OSW file
  puts "Loading OSW file to inspect seed model, files, and measures."
  osw = OpenStudio::WorkflowJSON.load("run/workflows/#{workflow_name}/in.osw").get
  runner = OpenStudio::Measure::OSRunner.new(osw)
  workflow = runner.workflow

  # saving osw early so I use findMeasure to copy to short path
  puts "Make a copy of OSW named workflow.osw which is what OS App Expexts"
  osw_path = "run/workflows/#{workflow_name}/workflow.osw"
  workflow.saveAs(osw_path)

  # copy seed file
  puts "Creating OSM named after workflow that is copy of seed model from OSW file."
  source_seed = "seeds/#{workflow.seedFile.get}"
  target_seed = "run/workflows/#{workflow_name}.osm"
  FileUtils.copy_entry(source_seed, target_seed)

  # copy measures
  puts "Copying measures in #{workflow_name} to run/workflows/#{workflow_name}/measures directory."
  short_path = "run/workflows/#{workflow_name}/measures"
  FileUtils.mkdir_p(short_path)

  # make directory if does not exist
  FileUtils.mkdir_p("run/workflows/#{workflow_name}/files")

  # store string argument names to cross check against weather files
  string_args = []

  # find path in measures used in osw and copy them to short path
  workflow.workflowSteps.each do |step|
    if step.to_MeasureStep.is_initialized
      measure_step = step.to_MeasureStep.get
      measure_dir_name = measure_step.measureDirName

      # set display name for os app (update to check if name exists first)
      measure_step.setName(measure_dir_name)

      # copy measure
      source_path = workflow.findMeasure(measure_dir_name.to_s).get.to_s
      FileUtils.copy_entry(source_path, "#{short_path}/#{measure_dir_name}")

      # populate string arguments
      skip = false
      measure_step.arguments.each do |arg_name,arg_val|
        string_args << arg_val.to_s
        if arg_val.to_s.include? ".epw"
          string_args << arg_val.to_s.gsub(".epw",".ddy")
          string_args << arg_val.to_s.gsub(".epw",".stat")
        end
        if arg_name.to_s == "__SKIP__" && arg_val.to_s == 'true'
          skip = true
        end
      end

      # todo - delete measures from workflow that are set to skip in OSW, but I still want to keep measures in place (HPXMLtoOpenStudio is used by many measures)
      # while it seems to run with them in the OSW but skipped it is confusing because they show up in OS app and unlike PAT  no indication of skip state or way to change it.
      if skip
        # todo - there is now workfow.removeMeasure or similar function, I cold try to edit as JSON, but will just update view name for now
        puts "flagging #{measure_dir_name} in GUI display name that are skipped, didn't see easy way to remove measure from workflow."
        measure_step.setName("***** Measure Skipped on Purpose ***** (#{measure_dir_name} will not run with other measures)")
      end

    end
  end

  # save workflow with updated measure names
  workflow.save

  # copy weather file (also ddy and stat) and other files that may be used
  # todo - might have to get everyting in files dir, maybe even all seed models for replace model (could cross check for arg names in workflow)
  if workflow.weatherFile.is_initialized
    puts "copying weather file from OSW"
    source_weather = workflow.findFile(weather_file).get
    target_weather = "run/workflows/files/#{weather_file}"
    FileUtils.copy_entry(source_weather,target_weather)
  end

  # look through weather files and copy as needed
  weather_files = Dir.entries('weather')
  weather_files.each do |weather_file|
    next if [".",".."].include? weather_file
    if string_args.include? weather_file
      puts "copying #{weather_file} used by measure in workflow"
      FileUtils.copy_entry("weather/#{weather_file}","run/workflows/#{workflow_name}/files/#{weather_file}")
    end
  end

  # loop through files
  other_files = Dir.entries('files')
  other_files.each do |other_file|
    next if [".",".."].include? other_file
    if string_args.include? other_file
      puts "copying #{other_file} used by measure in workflow"
      FileUtils.copy_entry("files/#{other_file}","run/workflows/#{workflow_name}/files/#{other_file}")
    end
  end

  puts "You should be able to open and run workflow for #{workflow_name} in the OpenStudio Application by opening #{workflow_name}.osm"

end

desc 'In Run directory Setup OSW with OSM so can be opened and run in OpenStudio Applicaiton'
task :setup_os_app , [:workflow_name] do |task, args|
  args.with_defaults(workflow_name: 'bar_typical')

  setup_os_app(args[:workflow_name])
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
