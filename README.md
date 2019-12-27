# osw2osa
This repo is a sample deployment of ruby scripts used to generate OSA files from template OSW and OSA files. This creates the analysis JSON file as well as the ZIP file containing measures, weather, seed models,  analysis scripts, and other resources. The script supports defining variable values for measure arguments found in the template OSW file. You can run the script with a clean checkout by calling `ruby osw_2_osa_rb` from the top level of the repository. This will populate the run directory with a JSON and ZIp file for the default analysis described in 'custom_var_set_mappping.rb'

- Repository File Structure
    - workflows
        - This contains OSW files that can be run on their own, or used with `osw_2_osa.rb` to setup one or multiple OSA files.
        - bar_typical
        - blend_typical (this is not ready for use with script)
        - floorspace_typical
        - osm_typical (does not exist, will import osm with stub space types using ReplaceModel and run create_typical measure. Measure is not on public repo yet)
    - measures
        - Currently this contains a measure to merge a `FloorspaceJS` file into an OpenStudio model. This will be moved to another public repository soon.
        - You would generally use this for single purpose measures that don't exist in another repository and that you don't think will be useful outside of the current project you are setting up.
        - Seed models that will be used by one or more of the template OSW files and the resulting OSA files.
    - weather
        - Contains weather files that are used by OSW, OSA, or by measures such as the `ChangeBuildingLocaiton` which requires additional EPW, DDY, and STAT files.
    - seeds
        - Seed models that will be used by one or more of the template OSW files and the resulting OSA files.
    - files
        - This contains files that are be used by measures when an OSW or OSA is run. This includes `geojson` and `FloorspaceJS` json files, but may also include any file needed by a measure that isn't already contained within the measure.
    - osw_2_osa.rb
        - This script is the primary file for the repository that everything else supports. The script arguments are described later in this readme. This is currently just setup for discrete variables, but could support more in the future.
    - custom_var_set_mapping.rb
        - This is called by `osw_2_osa.rb` to identify the mapping for variables, OSA template, and the source OSW.
        - Methods in script
            - `valid_var_sets` is just basic error handeling to look for unexpected arguments passed in for argument in main script
            - `selected_var_set` determines the default variable set to use if argument is not passed in. For basic use cases with one one primary analysis this makes calling the script cleaner.
            - `select_osw` is used to pick the template OSW based on the `var_set` unless the user specifically enters an argument for a specific template OSW.
            - `select_osa` is used pick the template OSA if an argument for this isn't passed in by the user.
            - `var_mapping` sets up discrete variables in the final OSA. This can be enhanced in the future to support other variable types.
            - `update_static_arg_val` can be used to alter static argument values for a specific analysis. This can be used to change a default value from what is in an OSW, or can be used to skip measures in an OSW by making use of the `__SKIP__` argument and setting it it `true`. This allows you to get more use out of a smaller number of OSW files which is easier ot maintain as you make chagnes or add reports.
    - template_osa_files
        - The template OSA files are used for their output variables, objective functions, algorithm settings, and their server scripts. 
        - If the template OSW has defined a seed model and weather file, it will be used in place of what is in the template OSA. 
        - The template OSA should have an empty `workflow` heading under the problem. That will be populated by `osw_2_osa` based on the template OSW and the variable logic in the script.
        - Current templates use design of experiments algorithm (DOE) and SingleRun, but other algorithms can be added.
    - analysis_scripts
        - This contains an exmaple worker initialization script that installs a custom version of the `openstudio-standards` gem for an analysis.
    - run (only on local checkout)
        - after you run 'osw_2_osa.rb' this directory will be generated and populated with analysis JSON files and an analysis zip file. These are what are required by the OpenStudio meta-CLI to run an analysis.
- Additional public repositories need to be checked out to setup the example analysis projects using `osw_2_osa.rb`. (I may use gem install at some point to get sample measures). These repositories contain most of the measured used by the workflow. The paths in OSW assume these repositories are checked out next to the osw2osa repository.
    - https://github.com/NREL/openstudio-model-articulation-gem/tree/develop
    - https://github.com/NREL/openstudio-common-measures-gem/tree/develop
    - https://github.com/urbanopt/urbanopt-geojson-gem/tree/develop
    - https://github.com/macumber/openstudio-vA3C/tree/master
- Script Arguments
    - ARGV[0] json file is generated unless false. Default value is true.
    - ARGV[1] zip file is generated unless false. Default value is true.
    - ARGV[2] variable set name. Default value is `generic`. Other example variable sets are listed below. These are defined by the `custom_var_set_mapper.rb` file.
        - generic
        - pv_fraction
        - pv_bool
        - bar_study_1
        - bar_study_2
    - ARGV[3] parent directory name for source osw (can also be picked based on analysis name in ARGV[3]). Default varies based on variable set. Currently the expected OSW name is `in.osw` within the selected directory.
    - ARG[4] file name for template osa. Default value is `osa_template_doe`.
- Testing
    - Tested using develop checkout of source repositories as of 12/26 using OpenStudio 2.9.0. Tested local OSW runs, and OpenStudio Server based OSA runs.
- Future code development tasks
    - Update to use 2.9.0 version of measures and test
    - add configuration to adjust local path to checkout of other repos, unless I instead use rake and bundle to install gems here with gemspec file to define branch.
    - Figure out how to get OSA to work with `runner.workflow.FindPath` instead having to set relative path for use with OSA, while it seems the path is wrong for OSW run, extra file paths are added into OSW when it is run.

Run Individual Workflow using CLI using 
<br>`openstudio run --workflow /path/to/workflow.osw`. 
<br>
<br>To run measure only for testing use 
<br>`openstudio run --measures_only --workflow /path/to/workflow.osw`

Below is a sample command line call to run `osw_2_osa.rb`. The script does use OpenStudio runner methods so it is necessary for your system ruby to be able `require openstudio`. In this example the template OSW and OSA are not passed in, so it will be selected based on the variable set`bar_study_1`.
<br>`ruby osw_2_osa.rb true true bar_study_1`

Run OSA files generated by `osw_2_osa.rb` using the OpenStudio meta CLI using code similar to 
<br>`openstudio_meta run_analysis --debug --verbose --ruby-lib-path="/Applications/OpenStudio-2.9.0/ParametricAnalysisTool.app/Contents/Resources/ruby" "osw_2_osa_pv_bool.json" "http://already_running_os_server_url:8080/" -a doe`
