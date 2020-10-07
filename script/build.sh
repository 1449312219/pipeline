#./pipeline-build.sh $@
#./init-build.sh $@
#./pipeline-build.sh Release- ci

projectName=test

function addNamespace() {
  sed -e "/^metadata:/a\  namespace: ${projectName}-pipeline" -e "/namespace/d"
}

# branchType env1 env2 env3 (流水线内的环境)
./branch-push-build.sh | addNamespace

# branchType manifestSuffix webhook env1 env2 env3 (需创建flux的环境)
./flux-init-build.sh | addNamespace
