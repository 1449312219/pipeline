set -ex

host=$1
port=$2

hostPath=$(mktemp .host.XXXXXXXXXX -u)
ssh-keyscan -p $port $host 2>/dev/null >$hostPath

keyPath=$(mktemp .key.XXXXXXXXXX -u)
ssh-keygen -qN "" -C "pipeline@no.user.com" -f $keyPath

token=$3


set +e

kubectl apply -f - <<EOF

apiVersion: v1
kind: ServiceAccount
metadata:
  name: pipeline-git-ssh
secrets:
- name: pipeline-git-ssh
---

apiVersion: v1
kind: Secret
metadata:
  name: pipeline-git-ssh
  annotations:
    tekton.dev/git-0: 10.1.40.43:30220
type: kubernetes.io/ssh-auth
stringData:
  ssh-privatekey: |
$(cat $keyPath|awk '{print "    "$0}')
  known_hosts: |
$(cat $hostPath|awk '{print "    "$0}')
---

apiVersion: v1
kind: Secret
metadata:
  name: gitea-user-token
stringData:
  token: $token

EOF

cat $keyPath.pub
#rm $hostPath $keyPath $keyPath.pub -f
