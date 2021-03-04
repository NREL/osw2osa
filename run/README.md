# Run Directory
The run directory is ignored for this repository on all other branches except for pre_bundled. It is saved on this branch so users can run the OSW files without having to use their system Ruby, bundle install, and rake tasks. From time to time the measures and workflows here will be updated from master, but this will not be merged into master. Do not develop any code on  this branch.

Run Individual Workflow using CLI using 
<br>`openstudio run --workflow /path/to/workflow.osw`. 
<br>
<br>To run measure only for testing use 
<br>`openstudio run --measures_only --workflow /path/to/workflow.osw`
