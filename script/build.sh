# projectName purpose:envs:promotionType:args ...

. _help.sh

projectName=$1
fullRepoName=$(kubectl get configmap owner-config -o jsonpath={.data.owner})/${projectName}
shift

namespace=$(formatToNamespace ${fullRepoName})-pipeline
cat <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${namespace}
---

EOF

manifestSuffix="-manifest"

function purposeBuild() {
  local purpose=$1
  shift

  local promotionType=$1
  shift

  local args=$1
  shift

  # purpose promotionType args(branchType=...) env1 env2 env3 (流水线内的环境)
  ./promotion-build.sh $purpose $promotionType "namespace=${namespace};manifestSuffix=$manifestSuffix;$args" $events $@ | addNamespace ${namespace}
}


declare -A allEnvs
for config in $@; do
  parseArg $config
  # purpose:envs:promotionType:args

  purposeBuild $purpose $promotionType $args ${envs[@]}
  
  for env in ${envs[@]}; do
    allEnvs[$env]=$env
  done
done


# env1 env2 env3
./env-build.sh ${allEnvs[@]} | addNamespace ${namespace}


# basics
for file in $(findManifestPaths basics/); do
  cat $file | addNamespace ${namespace}
  printSplit
done


# gitea
./gitea-settings-build.sh ${projectName} ${manifestSuffix} ${namespace} 


# security
./security-build.sh ${fullRepoName} ${namespace} | addNamespace ${namespace}


# configmap
./resources.sh | addNamespace ${namespace}


# pv
cat templates/pv.yaml | PV_SUFFIX=${namespace} parsePlaceHolder 
printSplit


# conditions
cat ./test-cond.yaml | addNamespace ${namespace} 
