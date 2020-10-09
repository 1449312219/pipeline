. _help.sh

ENV_DIR=env

function printEnvYamls() {
  local env=$1

  for file in $(find ${ENV_DIR}/${env} -name '[^_]*.yaml' -! -name 'config.yaml' -type f); do
    cat $file
    printSplit
  done
}

for env in $@; do
  printEnvYamls $env
done
