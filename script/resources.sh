. _help.sh

DIR=templates/resources

function printConfigMap() {
  local name=$1
  local dir=${2:-$1}
  kubectl create configmap $name --from-file=$dir --dry-run=client -o yaml
  printSplit
}


cd $DIR
printConfigMap env-manifest
