#./pipeline-build.sh $@
#./init-build.sh $@
#./pipeline-build.sh Release- ci

# branchType env1 env2 env3 (流水线内的环境)
./branch-push-build.sh

# branchType manifestSuffix webhook env1 env2 env3 (需创建flux的环境)
./flux-init-build.sh
