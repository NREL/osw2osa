//Jenkins pipelines are stored in shared libaries. Please see: https://github.com/NREL/cbci_jenkins_libs 
 
@Library('cbci_shared_libs@osw2osaTesting') _

// Build for PR to develop branch only. 
if ((env.CHANGE_ID) && (env.CHANGE_TARGET) ) { // check if set

  openstudio_osw2osa()
    
}
