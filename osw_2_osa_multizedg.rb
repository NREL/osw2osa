# this will convert an OSW file to an OSA file
# additionally it can gather files for the analysis zip file
# It works by populating the workflow of a template OSA file with measure steps from the OSW
# ARGV[0] json file is generated unless false
# ARGV[1] zip file is generated unless false
# todo - add in arg for server name, nil if you don't want to send to server
# ARGV[2] analysis name
# ARGV[3] path relative path to source osw (can also be picked based on analysis name in ARGV[2])

# todo - break generic code used to do osw_2_osa to seprate file that is then called by this custom script
# todo - setup data file for variable sets instead of storing in the ruby script

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
  var_set = "location"
else
  var_set = ARGV[2]
  # supported var_set values
  # location (default)
  # constructions
  # hvac
  # swh (NA - is really about using different OSW for stratified tank)
  # central_swh
  # cz0a (central_swh)
  # cz0b (central_swh)
  # best
  # all (add in the future)
end

# valid variable sets
valid_sets = ['location','constructions','hvac','swh','best','central_swh','cz0a','cz0b']
if !valid_sets.include?(var_set)
  puts "this is an unexpected variable set, script is stopping"
  return false
end

if ARGV[3].nil?
  # add logic to use different default based on analysis chosen
  if ['swh','best'].include?(var_set)
    osw_path = OpenStudio::Path.new("../workflows/json_test_chicago_stratified_hpwh/floorplan.osw")
  elsif var_set == "cz0a"
    osw_path = OpenStudio::Path.new("../workflows/json_cz0a_central_swh/floorplan.osw")
  elsif var_set == "cz0b"
    osw_path = OpenStudio::Path.new("../workflows/json_cz0b_central_swh/floorplan.osw")
  elsif var_set == "central_swh"
    osw_path = OpenStudio::Path.new("../workflows/json_chicago_central_swh/floorplan.osw")
  else
    osw_path = OpenStudio::Path.new("../workflows/json_test_chicago/floorplan.osw")
  end
  puts "source OSW is #{osw_path}"
else
  osw_path = ARGV[3]
end

# todo - add argument for template OSA

# load a copy of template OSA file
project_name = "osw_2_osa_zedg_multi_#{var_set}"
osa_template_path = "osa_template_doe.json"
analysis_files_path = "analysis_files"
run_directory = "run"
Dir.mkdir(run_directory) unless File.exists?(run_directory)
osa_target_path = "#{run_directory}/#{project_name}.json"
zip_path = "#{run_directory}/#{project_name}.zip"
json = File.read(osa_template_path)
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
  zip_file.addDirectory("#{analysis_files_path}/scripts","scripts")

  # bring in external files (hard coded for now vs. dynamic from OSW)
  puts "adding external files to analysis zip"
  zip_file.addDirectory("#{analysis_files_path}/files","lib/files")

  # bring in all weather files
  puts "adding weather files to analysis zip"
  zip_file.addDirectory("../weather","weather")

end

# setup seed file
if workflow.seedFile.is_initialized
  seed_file = workflow.seedFile.get
  puts "setting seed file to #{seed_file}"
  hash["analysis"]["seed"]= {"file_type" => "OSM","path" => "./seeds/#{seed_file}"}
  if zip_file
    source_path = workflow.findFile(seed_file).get
    puts "adding seed model to analysis zip"
    zip_file.addFile(source_path,OpenStudio::Path.new("seeds/#{seed_file}"))
  end
end

# setup weather file
if workflow.weatherFile.is_initialized
  weather_file = workflow.seedFile.get
  puts "setting weather_file to #{weather_file}"
  hash["analysis"]["weather_file"]= {"file_type" => "OSM","path" => "./weather/#{weather_file}"}
  if zip_file
    source_path = workflow.findFile(weather_file).get
    zip_file.addFile(source_path,OpenStudio::Path.new("weather#{weather_file}"))
  end
end

# todo - I can't figure out how to setup an OSA to run with null seed or weather. While it is valid for an OSW, I don't know if it is valid for an OSA

# define discrete variables (nested hash of measure instance name and argument name)
desc_vars = {}

# weather_file
var_epw = []
if ['best','location'].include?(var_set)
  var_epw << 'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw' #8
  var_epw << 'USA_AZ_Davis-Monthan.AFB.722745_TMY3.epw' #2B
  var_epw << 'USA_CA_Chula.Vista-Brown.Field.Muni.AP.722904_TMY3.epw' #3C
  var_epw << 'USA_CO_Aurora-Buckley.Field.ANGB.724695_TMY3.epw' #5B
  var_epw << 'USA_FL_MacDill.AFB.747880_TMY3.epw' #2A
  var_epw << 'USA_GA_Atlanta-Hartsfield-Jackson.Intl.AP.722190_TMY3.epw' #3A
  var_epw << 'USA_HI_Honolulu.Intl.AP.911820_TMY3.epw' #1A
  var_epw << 'USA_MN_International.Falls.Intl.AP.727470_TMY3.epw' #7
  var_epw << 'USA_MN_Rochester.Intl.AP.726440_TMY3.epw' #6A
  var_epw << 'USA_MT_Great.Falls.Intl.AP.727750_TMY3.epw' #6B
  var_epw << 'USA_NM_Albuquerque.Intl.AP.723650_TMY3.epw' #4B
  var_epw << 'USA_NY_Buffalo-Greater.Buffalo.Intl.AP.725280_TMY3.epw' #5A
  var_epw << 'USA_NY_New.York-J.F.Kennedy.Intl.AP.744860_TMY3.epw' #4A
  var_epw << 'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw' #3B
  var_epw << 'USA_WA_Port.Angeles-William.R.Fairchild.Intl.AP.727885_TMY3.epw' #5C
  var_epw << 'USA_WA_Seattle-Tacoma.Intl.AP.727930_TMY3.epw' #4c
else
  #var_epw << 'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw' #8
  var_epw << 'USA_AZ_Davis-Monthan.AFB.722745_TMY3.epw' #2B
  var_epw << 'USA_CA_Chula.Vista-Brown.Field.Muni.AP.722904_TMY3.epw' #3C
  #var_epw << 'USA_CO_Aurora-Buckley.Field.ANGB.724695_TMY3.epw' #5B
  #var_epw << 'USA_FL_MacDill.AFB.747880_TMY3.epw' #2A
  var_epw << 'USA_GA_Atlanta-Hartsfield-Jackson.Intl.AP.722190_TMY3.epw' #3A
  #var_epw << 'USA_HI_Honolulu.Intl.AP.911820_TMY3.epw' #1A
  var_epw << 'USA_MN_International.Falls.Intl.AP.727470_TMY3.epw' #7
  #var_epw << 'USA_MN_Rochester.Intl.AP.726440_TMY3.epw' #6A
  #var_epw << 'USA_MT_Great.Falls.Intl.AP.727750_TMY3.epw' #6B
  #var_epw << 'USA_NM_Albuquerque.Intl.AP.723650_TMY3.epw' #4B
  var_epw << 'USA_NY_Buffalo-Greater.Buffalo.Intl.AP.725280_TMY3.epw' #5A
  #var_epw << 'USA_NY_New.York-J.F.Kennedy.Intl.AP.744860_TMY3.epw' #4A
  #var_epw << 'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw' #3B
  #var_epw << 'USA_WA_Port.Angeles-William.R.Fairchild.Intl.AP.727885_TMY3.epw' #5C
  #var_epw << 'USA_WA_Seattle-Tacoma.Intl.AP.727930_TMY3.epw' #4c
end
# chicago just in for testing, not part of climate zone set used for K12 and office ZEDG
#var_epw << 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'

# skip for CZ0
if !['cz0a','cz0b'].include?(var_set)
  desc_vars['ChangeBuildingLocation'] = {}
  desc_vars['ChangeBuildingLocation']['weather_file_name'] = var_epw
end

# setup variable for zero_energy_multifamily
desc_vars['zero_energy_multifamily'] = {}

# hvac_system
# for constructions and swh use static value from OSW which should be set ot Fain Coils + DOAS
if var_set == "hvac"
  var_hvac = []
  var_hvac << 'Minisplit Heat Pumps with DOAS'
  var_hvac << 'Minisplit Heat Pumps with ERVs'
  var_hvac << 'Four-pipe Fan Coils with central air-source heat pump with DOAS'
  var_hvac << 'Four-pipe Fan Coils with central air-source heat pump with ERVs'
  #var_hvac << 'PTHPs with DOAS'
  #var_hvac << 'PTHPs with ERVs'
  var_hvac << 'Water Source Heat Pumps with Boiler and Fluid-cooler with DOAS'
  var_hvac << 'Water Source Heat Pumps with Boiler and Fluid-cooler with ERVs'
  desc_vars['zero_energy_multifamily']['hvac_system_type'] = var_hvac
elsif ["best","central_swh","cz0a",'cz0b'].include?(var_set)
  var_hvac = []
  var_hvac << 'Minisplit Heat Pumps with DOAS'
  var_hvac << 'Minisplit Heat Pumps with ERVs'
  var_hvac << 'Four-pipe Fan Coils with central air-source heat pump with DOAS'
  var_hvac << 'Four-pipe Fan Coils with central air-source heat pump with ERVs'
  desc_vars['zero_energy_multifamily']['hvac_system_type'] = var_hvac
end

# wall_roof_construction_template and window_construction_template
# for best use static value from OSW
if var_set == "constructions"
  var_const_roof_wall = []
  var_const_roof_wall << '90.1-2019'
  var_const_roof_wall << 'Good'
  var_const_roof_wall << 'Better'
  var_const_roof_wall << 'ZE AEDG Multifamily Recommendations'
  desc_vars['zero_energy_multifamily']['wall_roof_construction_template'] = var_const_roof_wall
  var_const_window = []
  var_const_window << '90.1-2019'
  var_const_window << 'Good'
  var_const_window << 'Better'
  var_const_window << 'ZE AEDG Multifamily Recommendations'
  desc_vars['zero_energy_multifamily']['window_construction_template'] = var_const_window
elsif  ['hvac','swh'].include?(var_set)
  var_const_roof_wall = []
  var_const_roof_wall << '90.1-2019'
  var_const_roof_wall << 'ZE AEDG Multifamily Recommendations'
  desc_vars['zero_energy_multifamily']['wall_roof_construction_template'] = var_const_roof_wall
  var_const_window = []
  var_const_window << '90.1-2019'
  var_const_window << 'ZE AEDG Multifamily Recommendations'
  desc_vars['zero_energy_multifamily']['window_construction_template'] = var_const_window
end

# todo - infiltration (unless we can setup this happens with construction)

# todo - construction type for wall

# window to wall ratio all facades
# when if wanted to use second instance of measure key would be SetWindowToWallRatioByFacade_2
# for hvac use static value from OSW
if var_set == "constructions"
  var_wwr = [0.2,0.3,0.4]
  desc_vars['SetWindowToWallRatioByFacade'] = {}
  desc_vars['SetWindowToWallRatioByFacade']['wwr'] = var_wwr
elsif ['swh','best'].include?(var_set)
  var_wwr = [0.2,0.3]
  desc_vars['SetWindowToWallRatioByFacade'] = {}
  desc_vars['SetWindowToWallRatioByFacade']['wwr'] = var_wwr
end

# rotation
# for hvac and best use static value from osw
if var_set == "constructions"
  var_rotation = [0.0,45.0,90.0]
  desc_vars['RotateBuilding'] = {}
  desc_vars['RotateBuilding']['relative_building_rotation'] = var_rotation
elsif var_set == "swh"
  var_rotation = [0.0,90.0]
  desc_vars['RotateBuilding'] = {}
  desc_vars['RotateBuilding']['relative_building_rotation'] = var_rotation
end

# swh
if ['central_swh','cz0a','cz0b'].include?(var_set)
  var_swh = []
  var_swh << "Waste Water Heat Pump 140F Supply"
  var_swh << "Waste Water Heat Pump 120F Supply and Electric Tank"
  var_swh << "Waste Water Heat Pump 90F Supply and Electric Tank"
  desc_vars['multifamily_central_wwhp'] = {}
  desc_vars['multifamily_central_wwhp']['swh_type'] = var_swh
end

# populate workflow of OSA with steps from OSW
puts "processing source OSW"
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
vars = []
var_vals = []
puts "-----"
desc_vars.each do |k,v|
  measures_with_vars << k
  v.each do |k2,v2|
    puts "#{v2.size} variables for #{k2}: #{v2.inspect}"
    vars << k2
    var_vals << v2.size
  end
end
puts "-----"
puts "#{measures_with_vars.size} measures have variables #{measures_with_vars.inspect}."
puts "The analysis has #{vars.size} variables #{vars.inspect}."
puts "With DOE algorithm the analysis will have #{var_vals.inject(:*)} datapoints."

# todo - put a break in the script to see if the user wants to send the analysis to the server (if arg for server address is not nil)

# todo - add in meta-cli call here as well,
