@Library('dst-shared@master') _

dockerBuildPipeline {
 app = "spire-intermediate"
 name = "spire-intermediate"
 description = "Creates intermediate CA certificates for spire via vault"
 repository = "cray"
 imagePrefix = "cray"
        product = "csm"
 githubPushRepo = "Cray-HPE/spire-intermediate"
 githubPushBranches = /(release\/.*|master)/
}
