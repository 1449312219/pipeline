. _help.sh

ENV_DIR=env

function printEnvYamls() {
  local env=$1

  for file in $(findManifestPaths ${ENV_DIR}/${env} -! -name config.yaml); do
    cat $file
    printSplit
  done
}

for env in $@; do
  printEnvYamls $env
done
