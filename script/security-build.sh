. _help.sh

export PROJECT_NAME=$(formatToNamespace $1)
shift

export NAMESPACE=$1
shift

robotKeys=($(kubectl get secret robot-keys --no-headers -o custom-columns=token:data.token,git:.metadata.annotations.tekton\\.dev/git-0,hosts:data.known_hosts,key:data.ssh-privatekey))

export GITEA_USER_TOKEN=${robotKeys[0]}
export GIT_SERVER_SSH=${robotKeys[1]}
export KNOWN_HOSTS=${robotKeys[2]}
export SSH_PRIVATE_KEY=${robotKeys[3]}


TEMP_DIR=templates/security

for file in $(findManifestPaths ${TEMP_DIR}); do
  parsePlaceHolder $file
  printSplit 
done
