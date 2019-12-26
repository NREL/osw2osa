# this will convert an OSW file to an OSA file
# additionally it can gather files for the analysis zip file
# It works by populating the workflow of a template OSA file with measure steps from the OSW
# ARGV[0] json file is generated unless false
# ARGV[1] zip file is generated unless false
# ARGV[2] analysis name
# ARGV[3] parent directory name for source osw (can also be picked based on analysis name in ARGV[3])
# ARG[4] file name for template osa

# todo - setup data file for variable sets instead of storing in the ruby script, so this script doesn't have to be customized as much

# load dependencies
require 'fileutils'
require 'openstudio'
require 'json'

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
if ARGV[2].nil?
  # default to location sweep only
  var_set = "generic"
else
  var_set = ARGV[2]
end

# supported var_set values
valid_sets = ['generic','pv_fraction','pv_bool','bar_study_1','bar_study_2']
if !valid_sets.include?(var_set)
  puts "this is an unexpected variable set, script is stopping"
  return false
end

if ARGV[3].nil?
  # add logic to use different default based on analysis chosen
  if ['bar_study_1','bar_study_2','generic'].include?(var_set)
    osw_path = OpenStudio::Path.new("workflows/bar_typical/in.osw")
  else
    osw_path = OpenStudio::Path.new("workflows/floorspace_typical/in.osw")
  end
else
  osw_path = OpenStudio::Path.new("workflows/#{ARGV[3]}/in.osw")
end
puts "source OSW is #{osw_path}"
# todo - blend_typical will not work as osa until I fix argument for geojson_file path to be relative or using runner.workflow.findFile

if ARGV[4].nil?
  osa_template_path = OpenStudio::Path.new("template_osa_files/osa_template_doe.json")
else
  osa_template_path = OpenStudio::Path.new("template_osa_files/#{ARGV[4]}.json")
end
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
  puts "adding scripts to analysis zip"
  zip_file.addDirectory("analysis_scripts","scripts")

  # bring in external files (hard coded for now vs. dynamic from OSW)
  puts "adding external files to analysis zip"
  zip_file.addDirectory("resources","lib/resources")

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

# define discrete variables (nested hash of measure instance name and argument name)
desc_vars = {}

# weather_file
var_epw = []
if ['generic','bar_study_1'].include?(var_set)
  # var_epw << 'VNM_Hanoi.488200_IWEC.epw' #0A
  # var_epw << 'ARE_Abu.Dhabi.412170_IWEC.epw' #0B
  # var_epw << 'USA_HI_Honolulu.Intl.AP.911820_TMY3.epw' #1A
  # var_epw << 'IND_New.Delhi.421820_ISHRAE.epw' #1B
  # var_epw << 'USA_FL_MacDill.AFB.747880_TMY3.epw' #2A
  var_epw << 'USA_AZ_Davis-Monthan.AFB.722745_TMY3.epw' #2B
  var_epw << 'USA_GA_Atlanta-Hartsfield-Jackson.Intl.AP.722190_TMY3.epw' #3A
  # var_epw << 'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw' #3B
  var_epw << 'USA_CA_Chula.Vista-Brown.Field.Muni.AP.722904_TMY3.epw' #3C
  # var_epw << 'USA_NY_New.York-J.F.Kennedy.Intl.AP.744860_TMY3.epw' #4A
  # var_epw << 'USA_NM_Albuquerque.Intl.AP.723650_TMY3.epw' #4B
  # var_epw << 'USA_WA_Seattle-Tacoma.Intl.AP.727930_TMY3.epw' #4c
  var_epw << 'USA_NY_Buffalo-Greater.Buffalo.Intl.AP.725280_TMY3.epw' #5A
  # var_epw << 'USA_CO_Aurora-Buckley.Field.ANGB.724695_TMY3.epw' #5B
  # var_epw << 'USA_WA_Port.Angeles-William.R.Fairchild.Intl.AP.727885_TMY3.epw' #5C
  # var_epw << 'USA_MN_Rochester.Intl.AP.726440_TMY3.epw' #6A
  # var_epw << 'USA_MT_Great.Falls.Intl.AP.727750_TMY3.epw' #6B
  var_epw << 'USA_MN_International.Falls.Intl.AP.727470_TMY3.epw' #7
  # var_epw << 'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw' #8
else
  var_epw << 'USA_AZ_Davis-Monthan.AFB.722745_TMY3.epw' #2B
  var_epw << 'USA_GA_Atlanta-Hartsfield-Jackson.Intl.AP.722190_TMY3.epw' #3A

  # chicago used in OSW but not in OSA
  #var_epw << 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'
end

# variable for ChangeBuildingLocation
if var_epw.size > 0
  desc_vars['ChangeBuildingLocation'] = {}
  desc_vars['ChangeBuildingLocation']['weather_file_name'] = var_epw
end

# setup multiple variables for create_bar_from_building_type_ratios
desc_vars['create_bar_from_building_type_ratios'] = {}
desc_vars['create_typical_building_from_model'] = {} # used on worfkflow that doesn't have create_bar

# template
if ["bar_study_1","bar_study_2"].include?(var_set)
  var_template = []
  var_template << 'DOE Ref Pre-1980'
  var_template << 'DOE Ref 1980-2004'
  var_template << '90.1-2004'
  var_template << '90.1-2007'
  var_template << '90.1-2010'
  var_template << '90.1-2013'
  if osw_path.to_s.include?("floorspace_typical")
    desc_vars['create_typical_building_from_model']['template'] = var_template
  else
    desc_vars['create_bar_from_building_type_ratios']['template'] = var_template
  end
elsif ['generic'].include?(var_set)
  var_template = []
  var_template << '90.1-2004'
  var_template << '90.1-2013'
  if osw_path.to_s.include?("floorspace_typical")
    desc_vars['create_typical_building_from_model']['template'] = var_template
  else
    desc_vars['create_bar_from_building_type_ratios']['template'] = var_template
  end
end

# num_stories_above_grade
if ["bar_study_2"].include?(var_set)
  var_num_stories = [1.0,1.5,2.0,2.5,3.0] # when arg is integer instead of double store as string
  desc_vars['create_bar_from_building_type_ratios']['num_stories_above_grade'] = var_num_stories
elsif ["generic"].include?(var_set)
  var_num_stories = [1.0,2.0]
  desc_vars['create_bar_from_building_type_ratios']['num_stories_above_grade'] = var_num_stories
end

# fraction_of_surface or skip measure var
if var_set == "pv_fraction"
  var_fraction_pv = [0.25,0.375,0.5,0.625,0.75,0.875]
  desc_vars['add_rooftop_pv'] = {}
  desc_vars['add_rooftop_pv']['fraction_of_surface'] = var_fraction_pv
elsif var_set == "generic"
  var_fraction_pv = [0.5,0.75]
  desc_vars['add_rooftop_pv'] = {}
  desc_vars['add_rooftop_pv']['fraction_of_surface'] = var_fraction_pv
elsif ['pv_bool','generic'].include?(var_set)
  # you can use the __SKIP__ argument in any measure as a variable (this is not something that can be done in PAT)
  # I could have set fraction to 0 to mimic skipping, but just did it this way to demonstrate the functionality
  desc_vars['add_rooftop_pv'] = {}
  desc_vars['add_rooftop_pv']['__SKIP__'] = [true,false]
end

# todo - add in example showing how to handle variables on measures with multiple instances in a workflow
#  if wanted to use second instance of measure key would be SetWindowToWallRatioByFacade_2

# populate workflow of OSA with steps from OSW
puts "processing source OSW"
desc_vars_validated = {}
workflow.workflowSteps.each do |step|
  if step.to_MeasureStep.is_initialized

    measure_step = step.to_MeasureStep.get
    measure_dir_name = measure_step.measureDirName
    puts " - gathering data for #{measure_dir_name}"
    if zip_file
      source_path = workflow.findMeasure(measure_dir_name.to_s).get
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
      # remap argument that relies on external files in OSW that I have not figured out how to implement in OSA
      if k == "floorplan_path"
        arg_hash = {"name" => k,"value" => "../lib/files/#{v}"}
      else
        arg_hash = {"name" => k,"value" => v}
      end
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

# todo - add in warning if I choose custom OSW that doesn't have measure used as a variable, also update stats below

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
        puts "#{v2.size} variables for #{k2}: #{v2.inspect}"
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
