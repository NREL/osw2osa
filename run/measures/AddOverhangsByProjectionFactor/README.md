

###### (Automatically generated documentation)

# Add Overhangs by Projection Factor

## Description
Add overhangs by projection factor to specified windows. The projection factor is the overhang depth divided by the window height. This can be applied to windows by the closest cardinal direction. If baseline model contains overhangs made by this measure, they will be replaced. Optionally the measure can delete any pre-existing space shading surfaces.

## Modeler Description
If requested then delete existing space shading surfaces. Then loop through exterior windows. If the requested cardinal direction is the closest to the window, then add the overhang. Name the shading surface the same as the window but append with '-Overhang'.  If a space shading surface of that name already exists, then delete it before making the new one. This measure has no life cycle cost arguments. You can see the economic impact of the measure by costing the construction used for the overhangs.

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Projection Factor

**Name:** projection_factor,
**Type:** Double,
**Units:** overhang depth / window height,
**Required:** true,
**Model Dependent:** false




### Cardinal Direction

**Name:** facade,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false


**Choice Display Names** ["North", "East", "South", "West"]



### Remove Existing Space Shading Surfaces From the Model

**Name:** remove_ext_space_shading,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false




### Optionally Choose a Construction for the Overhangs

**Name:** construction,
**Type:** Choice,
**Units:** ,
**Required:** false,
**Model Dependent:** false


**Choice Display Names** []






