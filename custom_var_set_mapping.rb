# this is called by osw_2_osa.rb script. Generally this is the file that should be customized to define variable sets and template osw and osa files.

# list of valid_var_sets
def valid_var_sets
  return ['generic','pv_fraction','pv_bool','bar_study_1','bar_study_2']
end

# logic to select var set
def select_var_set
  if ARGV[2].nil?
    # default to location sweep only
    var_set = "generic"
  else
    var_set = ARGV[2]
  end
  return var_set
end

# todo - blend_typical will not work as osa until I fix argument for geojson_file path to be relative or using runner.workflow.findFile

# logic to select OSW
def select_osw(var_set)
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
  return osw_path
end

# logic to select OSA
def select_osa
  if ARGV[4].nil?
    osa_template_path = OpenStudio::Path.new("template_osa_files/osa_template_doe.json")
  else
    osa_template_path = OpenStudio::Path.new("template_osa_files/#{ARGV[4]}.json")
  end
  return osa_template_path
end

# logic define variables
def var_mapping(osw_path,var_set)
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

# template (note that depending on the workflow, a different measure is chosen to set template for)
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
# if wanted to use second instance of measure key would be SetWindowToWallRatioByFacade_2.
# I don't require or make use of the name field on the OSW, only the measure directory.

  return desc_vars
end