class AddMeters < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Add Meters"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make an argument for the reporting frequency
    reporting_frequency_chs = OpenStudio::StringVector.new
    reporting_frequency_chs << 'Hourly'
    reporting_frequency_chs << 'Timestep'
    reporting_frequency = OpenStudio::Measure::OSArgument::makeChoiceArgument('reporting_frequency', reporting_frequency_chs, true)
    reporting_frequency.setDisplayName('Reporting Frequency.')
    reporting_frequency.setDefaultValue('Hourly')
    args << reporting_frequency 

    return args
  
  end #end the arguments method
  
  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
	
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
	
    meter_names = ["Electricity:Facility","ExteriorLights:Electricity","InteriorLights:Electricity","InteriorEquipment:Electricity","ExteriorEquipment:Electricity","Fans:Electricity","Pumps:Electricity","Heating:Electricity","Cooling:Electricity","HeatRejection:Electricity","Humidifer:Electricity","HeatRecovery:Electricity","WaterSystems:Electricity","Cogeneration:Electricity","Gas:Facility","InteriorEquipment:Gas","ExteriorEquipment:Gas","Heating:Gas","Cooling:Gas","WaterSystems:Gas","Cogeneration:Gas","DistrictHeating:Facility","DistrictCooling:Facility"];
	
    meters = model.getOutputMeters
    #reporting initial condition of model
    runner.registerInitialCondition("The model started with #{meters.size} meter objects.")
	
    meter_names.each do |meter_name|
      add_flag = true
      
      # reporting_frequency
      reporting_frequency = runner.getStringArgumentValue('reporting_frequency', user_arguments) 

      # Two avoid two meters with the same name but different reporting frequencies, change the other to hourly.
      meters.each do |meter|
        if meter.name.to_s == meter_name
          old_frequency = meter.reportingFrequency
          runner.registerWarning("A meter named #{meter.name.to_s} already exists with reporting frequency #{old_frequency}. Changing frequency to #{reporting_frequency}.")
          meter.setReportingFrequency(reporting_frequency)
          add_flag = false
        end
      end
      
      if add_flag
        meter = OpenStudio::Model::OutputMeter.new(model)
        meter.setName(meter_name)
        meter.setReportingFrequency(reporting_frequency)
        meter.setMeterFileOnly(false)
      end      
    end
	
    meters = model.getOutputMeters
    #reporting final condition of model
    runner.registerFinalCondition("The model finished with #{meters.size} meter objects.")
	
    return true
	
  end #end the run method
  
end #end the measure

#this allows the measure to be use by the application
AddMeters.new.registerWithApplication