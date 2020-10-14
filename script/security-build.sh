. _help.sh

export NAMESPACE=$1


TEMP_DIR=templates/security

for file in $(findManifestPaths ${TEMP_DIR}); do
  parsePlaceHolder $file
  printSplit 
done
