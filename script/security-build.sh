. _help.sh

export NAMESPACE=$1


TEMP_DIR=templates/security

for file in $(find ${TEMP_DIR} -name '[^_]*.yaml' -type f); do
  parsePlaceHolder $file
  printSplit 
done
