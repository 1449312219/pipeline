. _help.sh

export PROJECT_NAME=$(formatToNamespace $1)
shift

export NAMESPACE=$1
shift

export GIT_SERVER_SSH=$(kubectl get configmap owner-config -o jsonpath={.data.git-server-ssh})

export KNOWN_HOSTS=$(echo $GIT_SERVER_SSH \
                     | sed -r '/:[0-9]+/ s|([^:]+):([^:]+)|ssh-keyscan -p \2 \1 2>/dev/null|e' \
                     | sed -r 's/.*/"&"/' )

robotKeys=($(kubectl get secret robot-keys --no-headers -o custom-columns=token:data.token,key:data.ssh-private-key))
export GITEA_USER_TOKEN=${robotKeys[0]}
export SSH_PRIVATE_KEY=${robotKeys[1]}


TEMP_DIR=templates/security

for file in $(findManifestPaths ${TEMP_DIR}); do
  parsePlaceHolder $file
  printSplit 
done
