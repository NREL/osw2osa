# osw2osa
Sample deployment of ruby script and file structure to generate OSA files with variable mapping from OSW file. This will create the analysis JSON file as well as the zip file containing measures, weather, seed moels,  analysis scripts, and other resources.

Documentation tasks
- document file structure of repo
- document other repos that need to be checked out (may use gem install at some point to get sample measures)
    - https://github.com/NREL/openstudio-model-articulation-gem/tree/develop
    - https://github.com/NREL/openstudio-common-measures-gem/tree/develop
    - https://github.com/macumber/openstudio-vA3C/tree/master
- document workflow
- document script arguments
- document how to use meta-cli to run analysis projects that are made

Code development tasks
- Update script to new file structure
- Move variable mapping into csv instead of script
- Maybe have analysis mapping that pick OSW and template OSA out similar to how variables are broken out
- Update to use 2.9.0 version of measure and test
- add configuration to adjust local path to checkout of other repos, unless I instead use rake and bundle to install gems here with gemspec file to define branch.

Run Individual Workflow using CLI using `openstudio run --workflow /path/to/workflow.osw`. To run measure only for testing use `openstudio run --measures_only --workflow /path/to/workflow.osw`
