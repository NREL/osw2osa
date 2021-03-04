# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

# start the measure
class AddOverhangsByProjectionFactor < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see
  def name
    return 'Add Overhangs by Projection Factor'
  end

  # human readable description
  def description
    return 'Add overhangs by projection factor to specified windows. The projection factor is the overhang depth divided by the window height. This can be applied to windows by the closest cardinal direction. If baseline model contains overhangs made by this measure, they will be replaced. Optionally the measure can delete any pre-existing space shading surfaces.'
  end

  # human readable description of modeling approach
  def modeler_description
    return "If requested then delete existing space shading surfaces. Then loop through exterior windows. If the requested cardinal direction is the closest to the window, then add the overhang. Name the shading surface the same as the window but append with '-Overhang'.  If a space shading surface of that name already exists, then delete it before making the new one. This measure has no life cycle cost arguments. You can see the economic impact of the measure by costing the construction used for the overhangs."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make an argument for projection factor
    projection_factor = OpenStudio::Measure::OSArgument.makeDoubleArgument('projection_factor', true)
    projection_factor.setDisplayName('Projection Factor')
    projection_factor.setUnits('overhang depth / window height')
    projection_factor.setDefaultValue(0.5)
    args << projection_factor

    # make choice argument for facade
    choices = OpenStudio::StringVector.new
    choices << 'North'
    choices << 'East'
    choices << 'South'
    choices << 'West'
    facade = OpenStudio::Measure::OSArgument.makeChoiceArgument('facade', choices)
    facade.setDisplayName('Cardinal Direction')
    facade.setDefaultValue('South')
    args << facade

    # make an argument for deleting all existing space shading in the model
    remove_ext_space_shading = OpenStudio::Measure::OSArgument.makeBoolArgument('remove_ext_space_shading', true)
    remove_ext_space_shading.setDisplayName('Remove Existing Space Shading Surfaces From the Model')
    remove_ext_space_shading.setDefaultValue(false)
    args << remove_ext_space_shading

    # populate choice argument for constructions that are applied to surfaces in the model
    construction_handles = OpenStudio::StringVector.new
    construction_display_names = OpenStudio::StringVector.new

    # putting space types and names into hash
    construction_args = model.getConstructions
    construction_args_hash = {}
    construction_args.each do |construction_arg|
      construction_args_hash[construction_arg.name.to_s] = construction_arg
    end

    # looping through sorted hash of constructions
    construction_args_hash.sort.map do |key, value|
      # only include if construction is not used on surface
      if !value.isFenestration
        construction_handles << value.handle.to_s
        construction_display_names << key
      end
    end

    # make an argument for construction
    construction = OpenStudio::Measure::OSArgument.makeChoiceArgument('construction', construction_handles, construction_display_names, false)
    construction.setDisplayName('Optionally Choose a Construction for the Overhangs')
    args << construction

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
    projection_factor = runner.getDoubleArgumentValue('projection_factor', user_arguments)
    facade = runner.getStringArgumentValue('facade', user_arguments)
    remove_ext_space_shading = runner.getBoolArgumentValue('remove_ext_space_shading', user_arguments)
    construction = runner.getOptionalWorkspaceObjectChoiceValue('construction', user_arguments, model)

    # check reasonableness of fraction
    projection_factor_too_small = false
    if projection_factor < 0
      runner.registerError('Please enter a positive number for the projection factor.')
      return false
    elsif projection_factor < 0.1
      runner.registerWarning("The requested projection factor of #{projection_factor} seems unusually small, no overhangs will be added.")
      projection_factor_too_small = true
    elsif projection_factor > 5
      runner.registerWarning("The requested projection factor of #{projection_factor} seems unusually large.")
    end

    # check the construction for reasonableness
    construction_chosen = true
    if construction.empty?
      handle = runner.getOptionalStringArgumentValue('construction', user_arguments)
      if handle.empty?
        runner.registerInfo('No construction was chosen.')
        construction_chosen = false
      else
        runner.registerError("The selected construction with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end

    else
      if !construction.get.to_Construction.empty?
        construction = construction.get.to_Construction.get
      else
        runner.registerError('Script Error - argument not showing up as construction.')
        return false
      end
    end

    # helper to make numbers pretty (converts 4125001.25641 to 4,125,001.26 or 4,125,001). The definition be called through this measure.
    def neat_numbers(number, roundto = 2) # round to 0 or 2)
      if roundto == 2
        number = format '%.2f', number
      else
        number = number.round
      end
      # regex to add commas
      number.to_s.reverse.gsub(/([0-9]{3}(?=([0-9])))/, '\\1,').reverse
    end

    # helper to make it easier to do unit conversions on the fly.  The definition be called through this measure.
    def unit_helper(number, from_unit_string, to_unit_string)
      converted_number = OpenStudio.convert(OpenStudio::Quantity.new(number, OpenStudio.createUnit(from_unit_string).get), OpenStudio.createUnit(to_unit_string).get).get.value
    end

    # helper that loops through lifecycle costs getting total costs under "Construction" or "Salvage" category and add to counter if occurs during year 0
    def get_total_costs_for_objects(objects)
      counter = 0
      objects.each do |object|
        object_LCCs = object.lifeCycleCosts
        object_LCCs.each do |object_LCC|
          if (object_LCC.category == 'Construction') || (object_LCC.category == 'Salvage')
            if object_LCC.yearsFromStart == 0
              counter += object_LCC.totalCost
            end
          end
        end
      end
      return counter
    end

    # counter for year 0 capital costs
    yr0_capital_totalCosts = 0

    # get initial construction costs and multiply by -1
    yr0_capital_totalCosts += get_total_costs_for_objects(model.getConstructions) * -1

    # reporting initial condition of model
    number_of_exist_space_shading_surf = 0
    shading_groups = model.getShadingSurfaceGroups
    shading_groups.each do |shading_group|
      if shading_group.shadingSurfaceType == 'Space'
        number_of_exist_space_shading_surf += shading_group.shadingSurfaces.size
      end
    end
    runner.registerInitialCondition("The initial building had #{number_of_exist_space_shading_surf} space shading surfaces.")

    # delete all space shading groups if requested
    if remove_ext_space_shading && (number_of_exist_space_shading_surf > 0)
      num_removed = 0
      shading_groups.each do |shading_group|
        if shading_group.shadingSurfaceType == 'Space'
          shading_group.remove
          num_removed += 1
        end
      end
      runner.registerInfo("Removed all #{num_removed} space shading surface groups from the model.")
    end

    # flag for not applicable
    overhang_added = false

    # loop through surfaces finding exterior walls with proper orientation
    sub_surfaces = model.getSubSurfaces
    sub_surfaces.each do |s|
      next if s.outsideBoundaryCondition != 'Outdoors'
      next if s.subSurfaceType == 'Skylight'
      next if s.subSurfaceType == 'Door'
      next if s.subSurfaceType == 'GlassDoor'
      next if s.subSurfaceType == 'OverheadDoor'
      next if s.subSurfaceType == 'TubularDaylightDome'
      next if s.subSurfaceType == 'TubularDaylightDiffuser'

      # get the absoluteAzimuth for the surface so we can categorize it
      absoluteAzimuth = OpenStudio.convert(s.azimuth, 'rad', 'deg').get + s.space.get.directionofRelativeNorth + model.getBuilding.northAxis
      absoluteAzimuth -= 360.0 until absoluteAzimuth < 360.0

      if facade == 'North'
        next if !((absoluteAzimuth >= 315.0) || (absoluteAzimuth < 45.0))
      elsif facade == 'East'
        next if !((absoluteAzimuth >= 45.0) && (absoluteAzimuth < 135.0))
      elsif facade == 'South'
        next if !((absoluteAzimuth >= 135.0) && (absoluteAzimuth < 225.0))
      elsif facade == 'West'
        next if !((absoluteAzimuth >= 225.0) && (absoluteAzimuth < 315.0))
      else
        runner.registerError('Unexpected value of facade: ' + facade + '.')
        return false
      end

      # delete existing overhang for this window if it exists from previously run measure
      shading_groups.each do |shading_group|
        shading_s = shading_group.shadingSurfaces
        shading_s.each do |ss|
          if ss.name.to_s == "#{s.name} - Overhang"
            ss.remove
            runner.registerWarning("Removed pre-existing window shade named '#{ss.name}'.")
          end
        end
      end

      if projection_factor_too_small
        # new overhang would be too small and would cause errors in OpenStudio
        # don't actually add it, but from the measure's perspective this worked as requested
        overhang_added = true
      else
        # add the overhang
        new_overhang = s.addOverhangByProjectionFactor(projection_factor, 0)
        if new_overhang.empty?
          ok = runner.registerWarning('Unable to add overhang to ' + s.briefDescription +
                   ' with projection factor ' + projection_factor.to_s + ' and offset ' + offset.to_s + '.')
          return false if !ok
        else
          new_overhang.get.setName("#{s.name} - Overhang")
          runner.registerInfo('Added overhang ' + new_overhang.get.briefDescription + ' to ' +
              s.briefDescription + ' with projection factor ' + projection_factor.to_s +
              ' and offset ' + '0' + '.')
          if construction_chosen
            if !construction.to_Construction.empty?
              new_overhang.get.setConstruction(construction)
            end
          end
          overhang_added = true
        end
      end
    end

    if !overhang_added
      runner.registerAsNotApplicable("The model has exterior #{facade.downcase} walls, but no windows were found to add overhangs to.")
      return true
    end

    # get final construction costs and multiply
    yr0_capital_totalCosts += get_total_costs_for_objects(model.getConstructions)

    # reporting initial condition of model
    number_of_final_space_shading_surf = 0
    final_shading_groups = model.getShadingSurfaceGroups
    final_shading_groups.each do |shading_group|
      number_of_final_space_shading_surf += shading_group.shadingSurfaces.size
    end
    runner.registerFinalCondition("The final building has #{number_of_final_space_shading_surf} space shading surfaces. Initial capital costs associated with the improvements are $#{neat_numbers(yr0_capital_totalCosts, 0)}.")

    return true
  end
end

# this allows the measure to be used by the application
AddOverhangsByProjectionFactor.new.registerWithApplication
