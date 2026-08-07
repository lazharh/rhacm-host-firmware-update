### an ansible set of playbooks
- plyabook.yml : updates the bios and bmc firmware (or one of them depending on what you define as url in vars). this applies to a single node in a singe spoke cluster via RHACM hub cluster
- playbook-batch.yml does the same as above but for multiple nodes and multipe clusters defined in vars/batch.yml
- sync-to-gitrepos.sh : syncs the files from the private folder where you have ansible credentials etc. to git/github repo folder and does the scrub (remove password or urls)
- Base on KCS that I published long time ago: https://access.redhat.com/articles/7138537 

### to get populate the vars:
- bmh; on the hub cluster run this command and select which not to upate BIOS/FW: oc get bmh -n your-spoke-namespace
- spoke node; run this command on the spoke cluster: oc get nodes 
- hub/spoke api url; on the corresponding cluster : oc whoami --show-server

