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

    # report final condition of model
    runner.registerFinalCondition("#{altered_space_types.size} space types were altered.")

    return true
  end
end

# register the measure to be used by the application
LabInputCustomization.new.registerWithApplication
