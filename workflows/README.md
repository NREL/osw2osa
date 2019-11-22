# Sample Workflows
OSA are based on one of the OSW's in this directory. If an argument is going to be used as a variable it needs to be listed in the OSW, otherwise the OSW doesn't need to list arguments that will use default measure values.

This directory has a separate OSW for bar and blended workflow. 
- One will also be added for FloorSpaceJS.
    - This could all be done in a single OSW overlaoded with all measures, where the osw2osa script turns specific measures on or off to enable a custom workflow. 
- Another can use replace building measure to load in an already existing completed model
- Tried to setup one using geojson, but hit some issues. Have to pass gem to CLI for 2.9.0, have to use full path for geojson since FindFile isn't used by the measure, and hitting sizing run issue. Will loko into those later.
