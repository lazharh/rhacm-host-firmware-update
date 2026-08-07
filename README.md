an ansible set of playbooks
- plyabook.yml : updates the bios and bmc firmware (or one of them depending on what you define as url in vars). this applies to a single node in a singe spoke cluster via RHACM hub cluster
- playbook-batch.yml does the same as above but for multiple nodes and multipe clusters defined in vars/batch.yml
- sync-to0gitrepo.sh : syncs the files from the private folder where you have ansible credentials etc. to git/github repo folder and does the scrub (remove password or urls)
- 
