# this will convert an OSW file to an OSA file
# additionally it can gather files for the analysis zip file
# It works by populating the workflow of a template OSA file with measure steps from the OSW
# ARGV[0] json file is generated unless false
# ARGV[1] zip file is generated unless false
# ARGV[2] variable set name
# ARGV[3] parent directory name for source osw (can also be picked based on analysis name in ARGV[3])
# ARG[4] file name for template osa

# load dependencies
require 'fileutils'
require 'openstudio'
require 'json'

# project specific customization should be handled by custom_var_set_mapping.rb
require './custom_var_set_mapping'

# setup arguments to control if json and zip files are made
if ARGV[0] == "false"
  make_json = false
else
  make_json = true
end
if ARGV[1] == "false"
  make_zip = false
else
  make_zip = true
end

# get default var_set
var_set = select_var_set

# supported var_set values
valid_sets = valid_var_sets
if !valid_sets.include?(var_set)
  puts "this is an unexpected variable set, please confirm requested var_set in custom variable set mapping file."
  return false
end

# use external file to select source OSW
osw_path = select_osw(var_set)
puts "source OSW is #{osw_path}"

osa_template_path = select_osa(var_set)
puts "template OSA is #{osa_template_path}"

# load a copy of template OSA file
project_name = "osw_2_osa_#{var_set}"
run_directory = "run"
Dir.mkdir(run_directory) unless File.exists?(run_directory)
osa_target_path = "#{run_directory}/#{project_name}.json"
zip_path = "#{run_directory}/#{project_name}.zip"
json = File.read(osa_template_path.to_s)
hash = JSON.parse(json)
puts "loading template OSA"

# update name and display name
base_display_name = hash["analysis"]["display_name"]
base_name = hash["analysis"]["name"]
hash["analysis"]["display_name"] = "#{hash["analysis"]["display_name"]}_#{var_set}"
hash["analysis"]["name"] = "#{hash["analysis"]["name"]}_#{var_set}"

# load OSW file
osw = OpenStudio::WorkflowJSON.load(osw_path).get
runner = OpenStudio::Measure::OSRunner.new(osw)
workflow = runner.workflow

# hash to name measures with multiple instances
measures_used_hash = {} # key is measure value is an array of instances, will help me to index name when used multiple times
var_used_hash = {} # key variable name value is number of instances of similar name, will help me to index name when used multiple times
workflow_index = 0

# make zip file
if make_zip

  zip_file = OpenStudio::ZipFile.new(zip_path,false)
  puts "generating analysis zip file"

  # bring in scripts (not from OSW)
  # todo - inspect selected OSA to see if any scripts are needed
  puts "adding scripts to analysis zip"
  zip_file.addDirectory("analysis_scripts","scripts")

  # bring in external files (hard coded for now vs. dynamic from OSW)
  puts "adding external files to analysis zip"
  zip_file.addDirectory("files","files")

  # bring in all weather files
  puts "adding weather files to analysis zip"
  zip_file.addDirectory("weather","weather")

end

# setup seed file
if workflow.seedFile.is_initialized
  seed_file = workflow.seedFile.get
  puts "setting seed file to #{seed_file}"
  hash["analysis"]["seed"]= {"file_type" => "OSM","path" => "./seeds/#{seed_file}"}
  if zip_file
    source_path = workflow.findFile(seed_file.to_s).get
    puts "adding seed model to analysis zip"
    zip_file.addFile(source_path,OpenStudio::Path.new("seeds/#{seed_file}"))
  end
end

# setup weather file
if workflow.weatherFile.is_initialized
  weather_file = workflow.weatherFile.get
  puts "setting weather_file to #{weather_file}"
  hash["analysis"]["weather_file"]= {"file_type" => "EPW","path" => "./weather/#{weather_file}"}
  # code below isn't necessary unless OSW weather file is not in the repo 'weather' directory
  if zip_file
    source_path = workflow.findFile(weather_file).get
    puts "confirming weather file is in analysis zip"
    zip_file.addFile(source_path,OpenStudio::Path.new("weather/#{weather_file}"))
  end
end

# todo - I can't figure out how to setup an OSA to run with null seed or weather. While it is valid for an OSW, I don't know if it is valid for an OSA

# define discrete variables (nested hash of measure instance name and argument name. Value is an array of variable values)
desc_vars = var_mapping(var_set,osw_path)

# store var_set specific changes to argument values
desc_args = update_static_arg_val(var_set)

# populate workflow of OSA with steps from OSW
puts "processing source OSW"
desc_vars_validated = {}
workflow.workflowSteps.each do |step|
  if step.to_MeasureStep.is_initialized

    measure_step = step.to_MeasureStep.get
    measure_dir_name = measure_step.measureDirName
    source_path = workflow.findMeasure(measure_dir_name.to_s).get
    puts " - gathering data for #{measure_dir_name} from #{source_path}."
    if zip_file
      zip_file.addDirectory(source_path,OpenStudio::Path.new("measures/#{measure_dir_name}"))
    end

    # check if measure already exists
    if measures_used_hash.has_key?(measure_dir_name)
      measures_used_hash[measure_dir_name] += 1
      inst_name = "#{measure_dir_name}_#{measures_used_hash[measure_dir_name]}"
    else
      inst_name = measure_dir_name
      measures_used_hash[measure_dir_name] = 1
    end

    new_workflow_measure = {}
    new_workflow_measure["name"] = inst_name.downcase # would be better to snake_case
    new_workflow_measure["display"] = inst_name.downcase # would be better to snake_case
    new_workflow_measure["measure_definition_directory"] = "./measures/#{measure_dir_name}"
    if measure_step.arguments.size > 0
      new_workflow_measure["arguments"] = []
    end
    measure_step.arguments.each do |k,v|
      if v.to_s == "true" then v = true end
      if v.to_s == "false" then v = false end

      # change arguments per var_set specifications
      # inst_name is measure_dir_name unless more than one instance exists when _# is added starting with _2
      if desc_args.has_key?(inst_name) && desc_args[inst_name].has_key?(k) && desc_args[inst_name][k] != v
        custom_val = desc_args[inst_name][k]
        puts "For #{k} argument in measure named #{inst_name} value from template OSW is being chagned to #{custom_val}"
        arg_hash = {"name" => k,"value" => custom_val}
      else
        arg_hash = {"name" => k,"value" => v}
      end

      # setup variables and arguments
      if desc_vars.has_key?(inst_name) && desc_vars[inst_name].has_key?(k)

        # update validated hash for reporting of script
        if !desc_vars_validated.has_key?(inst_name) then desc_vars_validated[inst_name] = {} end
        if !desc_vars_validated[inst_name].has_key?(k) then desc_vars_validated[inst_name][k] = [] end

        # setup variable
        if !new_workflow_measure.has_key?("variables")
          new_workflow_measure["variables"] = []
        end
        new_var = {}
        new_workflow_measure['variables'] << new_var
        new_var['argument'] = arg_hash
        if var_used_hash.has_key?(k)
          var_used_hash[k] += 1
          new_var['display_name'] = "#{k}_#{var_used_hash[k]}"
        else
          var_used_hash[k] = 1
          new_var['display_name'] = k
        end
        new_var['variable_type'] = 'variable'
        new_var['variable'] = true
        new_var['static_value'] = v
        new_var['uncertainty_description'] = {}
        new_var['uncertainty_description']['type'] = 'discrete'
        new_var['uncertainty_description']['attributes'] = []
        attribute_hash = {}
        attribute_hash['name'] = 'discrete'
        values_and_weights = []
        desc_vars[inst_name][k].each do |val|
          # weight not important for DOE but may want to store with values for other use cases
          values_and_weights << {'value' => val, 'weight' => 1.0/desc_vars[inst_name][k].size}
          desc_vars_validated[inst_name][k] << val
        end
        attribute_hash['values_and_weights'] = values_and_weights
        new_var['uncertainty_description']['attributes'] << attribute_hash
      else
        # setup argument
        new_workflow_measure["arguments"] << arg_hash
        if !new_workflow_measure.has_key?("variables")
          new_workflow_measure["variables"] = []
        end
      end

    end
    new_workflow_measure["workflow_index"] = workflow_index
    workflow_index += 1
    hash["analysis"]["problem"]["workflow"] << new_workflow_measure

  else
    #puts "This step is not a measure"
  end

end

# save OSW file
if make_json
  puts "saving modified OSA"
  #puts JSON.pretty_generate(hash)
  hash.to_json
  File.open(osa_target_path, "w") do |f|
    f.puts JSON.pretty_generate(hash)
  end
end

# report number of variables
measures_with_vars = []
missing_measures_with_vars = []
vars = []
var_vals = []
puts "-----"
# desc_vars
# desc_vars_validated
desc_vars.each do |k,v|
  next if v.size == 0
  if ! desc_vars_validated.has_key?(k)
    missing_measures_with_vars << k
    puts "**** #{osw_path} at doesn't have a measure named #{k}, requested variables will be ignored for osa generation. ****"
  else
    measures_with_vars << k
    v.each do |k2,v2|

      if ! desc_vars_validated[k].has_key?(k2)
        puts "**** #{osw_path} at doesn't have a measure argument named #{k2} for measure #{k}, requested variable will be ignored for osa generation. ****"
      else
        puts "#{v2.size} values for #{k} #{k2}: #{v2.inspect}"
        vars << k2
        var_vals << v2.size
      end
    end
  end
end
puts "-----"
puts "#{measures_with_vars.size} measures have variables #{measures_with_vars.inspect}."
puts "The analysis has #{vars.size} variables #{vars.inspect}."
puts "With DOE algorithm the analysis will have #{var_vals.inject(:*)} datapoints."
if vars.size < 2
  puts "**** warning analysis has only one variable, may not work with some algorithms that require 2 or more variaibles. *****"
end
