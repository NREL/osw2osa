# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'json'

# start the measure
class MergeFloorspaceJsWithModel < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Merge FloorspaceJs with Model'
  end

  # human readable description
  def description
    return 'This measure will import a FloorspacJS JSON file into an OpenStudio model. This is meant to function in similar way to the merge function in the geometry editor of the OpenStudio Applicaiton.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'This measure is based off of the ResidentialGeometryCreateFromFloorspaceJS measure on the OpenStudio-Buildstock repository'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # path to the floorplan JSON file to load
    floorplan_path = OpenStudio::Ruleset::OSArgument.makeStringArgument("floorplan_path", true)
    floorplan_path.setDisplayName("Floorplan Path")
    floorplan_path.setDescription("Path to the floorplan JSON.")
    args << floorplan_path

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
    floorplan_path = runner.getStringArgumentValue("floorplan_path", user_arguments)

    # check the floorplan_path for reasonableness
    if floorplan_path.empty?
      runner.registerError("Empty floorplan path was entered.")
      return false
    end

    path = runner.workflow.findFile(floorplan_path)
    if path.empty?
      runner.registerError("Cannot find floorplan path '#{floorplan_path}'.")
      return false
    end

    json = nil
    File.open(path.get.to_s, 'r') do |file|
      json = file.read
    end

    floorplan = OpenStudio::FloorplanJS::load(json)
    if floorplan.empty?
      runner.registerError("Cannot load floorplan from '#{floorplan_path}'.")
      return false
    end

    scene = floorplan.get.toThreeScene(true)
    rt = OpenStudio::Model::ThreeJSReverseTranslator.new
    new_model = rt.modelFromThreeJS(scene)

    unless new_model.is_initialized
      runner.registerError("Cannot convert floorplan to model.")
      return false
    end
    new_model = new_model.get

    runner.registerInitialCondition("Initial model has #{model.getPlanarSurfaceGroups.size} planar surface groups.")

    mm = OpenStudio::Model::ModelMerger.new
    mm.mergeModels(model, new_model, rt.handleMapping)

    mm.warnings.each do |warnings|
      runner.registerWarning(warnings.logMessage)
    end

    # put all of the spaces in the model into a vector
    spaces = OpenStudio::Model::SpaceVector.new
    model.getSpaces.each do |space|
      spaces << space
    end

    # intersect and match surfaces for each space in the vector
    # todo - add in diagnostic intersect as option
    OpenStudio::Model.intersectSurfaces(spaces)
    OpenStudio::Model.matchSurfaces(spaces)

    json = JSON.parse(File.read(path.get.to_s))

    # error checking
    unless json["space_types"].length > 0
      runner.registerInfo("No space types were created.")
    end

    # set the space type standards fields based on what user wrote in the editor
    json["space_types"].each do |st|
      model.getSpaceTypes.each do |space_type|
        next unless space_type.name.to_s.include? st["name"]
        next if space_type.standardsSpaceType.is_initialized

        space_type.setStandardsSpaceType(st["name"])
      end
    end

    # remove any unused space types
    model.getSpaceTypes.each do |space_type|
      if space_type.spaces.length == 0
        space_type.remove
      end
    end

    # for any spaces with no assigned zone, create (unless another space of the same space type has an assigned zone) a thermal zone based on the space type
    # todo - add argument to enable disable zone creation
    model.getSpaceTypes.each do |space_type|
      space_type.spaces.each do |space|
        unless space.thermalZone.is_initialized
          thermal_zone = OpenStudio::Model::ThermalZone.new(model)
          thermal_zone.setName(space.name.to_s)
          space.setThermalZone(thermal_zone)
        end
      end
    end

    # report final condition of model
    runner.registerFinalCondition("Final model has #{model.getPlanarSurfaceGroups.size} planar surface groups.")

    return true
  end
end

# register the measure to be used by the application
MergeFloorspaceJsWithModel.new.registerWithApplication
