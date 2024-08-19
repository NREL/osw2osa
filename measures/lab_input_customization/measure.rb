# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class LabInputCustomization < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Lab Input Customization'
  end

  # human readable description
  def description
    return 'Alter various inupts different from create_typical lab'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Initially this will be on internal loads but may be expanded as needed'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make choice argument for lab type
    choices = OpenStudio::StringVector.new
    choices << 'Dry Lab'
    choices << 'Wet Chem Low Haz'
    choices << 'Wet Chem High Haz'
    choices << 'High Bay Low Haz'
    choices << 'High Bay High Haz'
    lab_type = OpenStudio::Measure::OSArgument.makeChoiceArgument('lab_type', choices, true)
    lab_type.setDisplayName('Cardinal Direction.')
    lab_type.setDefaultValue('Dry Lab')
    args << lab_type

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)  # Do **NOT** remove this line

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    lab_type = runner.getStringArgumentValue('lab_type', user_arguments)

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getSpaceTypes.size} space types.")
    altered_space_types = []

    # lab customization values
    # vent units cfm/ft^2
    # plug units W/ft^2
    lab_customization_vals = {}
    lab_customization_vals['Dry Lab'] = {:vent => 1.0, :plug => 100.0}
    lab_customization_vals['Wet Chem Low Haz'] = {:vent => 3.5, :plug => 36.0}
    lab_customization_vals['Wet Chem High Haz'] = {:vent => 3.5, :plug => 36.0}
    lab_customization_vals['High Bay Low Haz'] = {:vent => 3.5, :plug => 100.0}
    lab_customization_vals['High Bay High Haz'] = {:vent => 1.0, :plug => 100.0}
    lab_customization_vals['Laboratory Equipment corridor'] = {:vent => 1.0, :plug => 24.0}

    # loop through space tyoes
    model.getSpaceTypes.each do |space_type|
      # skip of not used in model
      next if space_type.spaces.empty?

      # get standards building
      if !space_type.standardsBuildingType.empty?
        standards_building_type = space_type.standardsBuildingType.get
      else
        next
      end
      next if !standards_building_type == "Laboratory"

      # get standards space type
      if !space_type.standardsSpaceType.empty?
        standards_space_type = space_type.standardsSpaceType.get
      else
        next
      end
      runner.registerInfo("Evaulating #{standards_building_type}:#{standards_space_type}")

      if standards_space_type == 'Lab with fume hood'

        # alter lab with fume hood plug
        plug_si = OpenStudio.convert(lab_customization_vals[lab_type][:plug],'W/ft^2','W/m^2').get
        space_type.setElectricEquipmentPowerPerFloorArea(plug_si)
        new_lab_cor_elec_equip = space_type.electricEquipment[0]
        new_lab_cor_elec_equip_def = new_lab_cor_elec_equip.electricEquipmentDefinition
        new_lab_cor_elec_equip_def.setName("Custom Lab #{lab_type} Plug Load per area or lab with fume hood")
        runner.registerInfo("Setting electric equipment for #{new_lab_cor_elec_equip_def.name} to #{lab_customization_vals[lab_type][:plug]} (W/ft^2)")

        # alter ab with fume hood vent
        if !space_type.designSpecificationOutdoorAir.empty?
          vent_si = OpenStudio.convert(lab_customization_vals[lab_type][:vent],'ft/min','m/hr').get
          vent = space_type.designSpecificationOutdoorAir.get
          vent.setOutdoorAirFlowperFloorArea(vent_si)
          vent.setOutdoorAirFlowperPerson(0.0)
          vent.setOutdoorAirFlowAirChangesperHour(0.0)
          vent.setName("Custom Lab #{lab_type} Ventilation per area for or lab with fume hood")
          runner.registerInfo("Setting ventilation for #{vent.name} to #{lab_customization_vals[lab_type][:vent]} (cfm/ft^2).")
        else
          runner.registerInfo("Did not finddesignSpecificationOutdoorAir for #{space_type.name}")
        end        

      elsif standards_space_type == 'Equipment corridor'

        # alter lab_cor plug
        plug_si = OpenStudio.convert(lab_customization_vals['Laboratory Equipment corridor'][:plug],'W/ft^2','W/m^2').get
        space_type.setElectricEquipmentPowerPerFloorArea(plug_si)
        new_lab_cor_elec_equip = space_type.electricEquipment[0]
        new_lab_cor_elec_equip_def = new_lab_cor_elec_equip.electricEquipmentDefinition
        new_lab_cor_elec_equip_def.setName("Custom Lab Corridor Plug Load per area")
        runner.registerInfo("Setting electric equipment for #{new_lab_cor_elec_equip_def.name} to #{lab_customization_vals['Laboratory Equipment corridor'][:plug]} (W/ft^2)")

        # alter lab_cor vent
        if !space_type.designSpecificationOutdoorAir.empty?
          vent_si = OpenStudio.convert(lab_customization_vals['Laboratory Equipment corridor'][:vent],'ft/min','m/hr').get
          vent = space_type.designSpecificationOutdoorAir.get
          vent.setOutdoorAirFlowperFloorArea(vent_si)
          vent.setOutdoorAirFlowperPerson(0.0)
          vent.setOutdoorAirFlowAirChangesperHour(0.0)
          vent.setName("Custom Lab Corridor Ventilation per area")
          runner.registerInfo("Setting ventilation for #{vent.name} to #{lab_customization_vals['Laboratory Equipment corridor'][:vent]} (cfm/ft^2).")
        else
          runner.registerInfo("Did not finddesignSpecificationOutdoorAir for #{space_type.name}")
        end

      else
        next
      end

      # add to array of altered space type
      altered_space_types << space_type
    end

    # report final condition of model
    runner.registerFinalCondition("#{altered_space_types.size} space types were altered.")

    return true
  end
end

# register the measure to be used by the application
LabInputCustomization.new.registerWithApplication
