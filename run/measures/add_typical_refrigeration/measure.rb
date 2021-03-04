require 'openstudio-standards'

# start the measure
class AddTypicalRefrigeration < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Add Typical Refrigeration'
  end

  # human readable description
  def description
    return 'Adds typical refrigeration equipment to a building'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Adds typical refrigeration equipment to a building'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # the name of the space to add to the model
    case_length_ft = OpenStudio::Measure::OSArgument.makeDoubleArgument('case_length_ft', true)
    case_length_ft.setDisplayName('Case Length (ft)')
    case_length_ft.setDefaultValue(30.0)
    args << case_length_ft

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    case_length_ft = runner.getDoubleArgumentValue('case_length_ft', user_arguments)

    # check the case_length_ft for reasonableness
    if case_length_ft < 0
      runner.registerError('Invalid case length.')
      return false
    elsif case_length_ft == 0.0
      runner.registerWarning('Case length is zero.  No cases will be added.')
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getRefrigerationCases.size} refrigerated cases.")

    # build standards template to access methods
    template = '90.1-2013'
    std = Standard.build(template)

    # get thermal zone to add display cases, typical largest space unless specified
    thermal_zone_case = std.model_typical_display_case_zone(model)
    if thermal_zone_case.nil?
      runner.registerError("Attempted to add a display case to the model, but could find no thermal zone to put it into.")
      return false
    end

    # create search properties
    case_type = 'Beverage Cases'
    system_type = 'Medium Temperature'
    size_category = ''
    building_type = 'QuickServiceRestaurant'
    compressor_name = 'MT compressor'
    compressor_type = 'Medium Temperature'

    search_criteria = {
      'template' => template,
      'building_type' => building_type,
      'case_type' => case_type,
      'size_category' => size_category,
      'compressor_name' => compressor_name
    }

    # add display case
    ref_case = std.model_add_refrigeration_case(model, thermal_zone_case, case_type, size_category)
    if ref_case.nil?
      runner.registerError("Unable to add refrigeration case.")
      return false
    end

    # create an array to hold cases
    display_cases = []
    display_cases << ref_case

    # set the case length
    case_length_m = OpenStudio.convert(case_length_ft, 'ft', 'm').get
    ref_case.setCaseLength(case_length_m)

    # Find defrost and dripdown properties
    props_case = std.model_find_object(std.standards_data['refrigerated_cases'], search_criteria)
    if props_case.nil?
      runner.registerError("Could not find refrigerated case properties for: #{search_criteria}.")
      return false
    end
    numb_defrosts_per_day = props_case['defrost_per_day']
    minutes_defrost = props_case['minutes_defrost']
    minutes_dripdown = props_case['minutes_dripdown']
    minutes_defrost = 59 if minutes_defrost > 59 # Just to make sure to remain in the same hour
    minutes_dripdown = 59 if minutes_dripdown > 59 # Just to make sure to remain in the same hour

    # Add defrost and dripdown schedules
    defrost_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    defrost_sch.setName('Refrigeration Defrost Schedule')
    defrost_sch.defaultDaySchedule.setName("Refrigeration Defrost Schedule Default - #{case_type}")
    dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    dripdown_sch.setName('Refrigeration Dripdown Schedule')
    dripdown_sch.defaultDaySchedule.setName("Refrigeration Dripdown Schedule Default - #{case_type}")

    # Stagger the defrosts for cases by 1 hr
    def_start_hr_iterator = 0
    interval_defrost = (24 / numb_defrosts_per_day).floor # Hour interval between each defrost period
    if (def_start_hr_iterator + interval_defrost * numb_defrosts_per_day) > 23
      first_def_start_hr = 0 # Start over again at midnight when time reaches 23hrs
    else
      first_def_start_hr = def_start_hr_iterator
    end

    # Add the specified number of defrost periods to the daily schedule
    (1..numb_defrosts_per_day).each do |defrost_of_day|
      def_start_hr = first_def_start_hr + ((1 - defrost_of_day) * interval_defrost)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, def_start_hr, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, def_start_hr, minutes_defrost.to_int, 0), 0)
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, def_start_hr, 0, 0), 0) # Dripdown is synced with defrost
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, def_start_hr, minutes_dripdown.to_int, 0), 0)
    end
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)

    # Assign the defrost and dripdown schedules
    ref_case.setCaseDefrostSchedule(defrost_sch)
    ref_case.setCaseDefrostDripDownSchedule(dripdown_sch)

    # add the refrigeration system
    ref_system_lineup = { 'ref_cases' => [ref_case], 'walkins' => [] }

    ##############################
    # Add the refrigeration system
    props_ref_system = std.model_find_object(std.standards_data['refrigeration_system'], search_criteria)
    if props_ref_system.nil?
      runner.registerError("Could not find refrigeration system properties for: #{search_criteria}.")
      return false
    end
    ref_system = OpenStudio::Model::RefrigerationSystem.new(model)
    ref_system.setName(system_type)
    ref_system.setRefrigerationSystemWorkingFluidType(props_ref_system['refrigerant'])
    ref_system.setSuctionTemperatureControlType(props_ref_system['refrigerant'])

    # Sum the capacity required by all cases and walkins
    # and attach the cases and walkins to the system.
    rated_case_capacity_w = 0
    ref_system_lineup['ref_cases'].each do |ref_case|
      rated_case_capacity_w += ref_case.ratedTotalCoolingCapacityperUnitLength * ref_case.caseLength
      ref_system.addCase(ref_case)
    end
    ref_system_lineup['walkins'].each do |walkin|
      rated_case_capacity_w += walkin.ratedCoilCoolingCapacity
      ref_system.addWalkin(walkin)
    end

    # Find the compressor properties
    props_compressor = std.model_find_object(std.standards_data['refrigeration_compressors'], search_criteria)
    if props_compressor.nil?
      runner.registerError("Could not find refrigeration compressor properties for: #{search_criteria}.")
      return false
    end

    # Calculate the number of compressors required to meet the
    # combined rated capacity of all the cases
    # and add them to the system
    rated_compressor_capacity_btu_per_hr = props_compressor['rated_capacity']
    number_of_compressors = (rated_case_capacity_w / OpenStudio.convert(rated_compressor_capacity_btu_per_hr, 'Btu/h', 'W').get).ceil
    (1..number_of_compressors).each do |compressor_number|
      compressor = std.model_add_refrigeration_compressor(model, compressor_name)
      ref_system.addCompressor(compressor)
    end
    runner.registerInfo("Added #{number_of_compressors} compressors, each with a capacity of #{rated_compressor_capacity_btu_per_hr.round} Btu/hr to serve #{OpenStudio.convert(rated_case_capacity_w, 'W', 'Btu/hr').get.round} Btu/hr of case and walkin load.")

    # Find the condenser properties
    props_condenser = std.model_find_object(std.standards_data['refrigeration_condenser'], search_criteria)
    if props_condenser.nil?
      runner.registerError("Could not find refrigeration condenser properties for: #{search_criteria}.")
      return false
    end

    # Heat rejection as a function of temperature
    heat_rejection_curve = OpenStudio::Model::CurveLinear.new(model)
    heat_rejection_curve.setName('Condenser Heat Rejection Function of Temperature')
    heat_rejection_curve.setCoefficient1Constant(0)
    heat_rejection_curve.setCoefficient2x(props_condenser['heatrejectioncurve_c1'])
    heat_rejection_curve.setMinimumValueofx(-50)
    heat_rejection_curve.setMaximumValueofx(50)

    # Add condenser
    condenser = OpenStudio::Model::RefrigerationCondenserAirCooled.new(model)
    condenser.setRatedEffectiveTotalHeatRejectionRateCurve(heat_rejection_curve)
    condenser.setRatedSubcoolingTemperatureDifference(OpenStudio.convert(props_condenser['subcool_t'], 'F', 'C').get)
    condenser.setMinimumFanAirFlowRatio(props_condenser['min_airflow'])
    condenser.setRatedFanPower(props_condenser['fan_power_per_q_rejected'].to_f * rated_case_capacity_w)
    condenser.setCondenserFanSpeedControlType(props_condenser['fan_speed_control'])
    ref_system.setRefrigerationCondenser(condenser)

    runner.registerInfo("Added #{system_type} refrigeration system")

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getRefrigerationCases.size} refrigerated cases.")

    return true
  end
end

# register the measure to be used by the application
AddTypicalRefrigeration.new.registerWithApplication
