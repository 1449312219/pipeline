set -ex
set -o pipefail

owner=$1
type=$2
repoName=$3
repoOwnerToken=$4
gitServerHttp=$5

namespace=${6:-promotion-promotion-${owner}-${repoName}}
repoStandardName=${owner}-${repoName}


kubectl create ns ${namespace}
kubectl="kubectl -n ${namespace}"


# load
$kubectl apply -f ./units
$kubectl apply -f ./init
$kubectl apply -f ./promotion
$kubectl apply -f ./promotion/branch-push
$kubectl apply -f ./promotion/gitea-chat


# config (security)
$kubectl create -f ./config -R --dry-run=client -o yaml \
| sed -e "s/\${NAMESPACE}/${namespace}/g" \
      -e "s/\${PROJECT_STANDARD_NAME}/${repoStandardName}/g" \
      -e "s/\${GITEA_USER_TOKEN}/${repoOwnerToken}/g" \
| $kubectl apply -f -


# init
$kubectl apply -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: add-project
spec:
  pipelineRef:
    name: add-project
  serviceAccountName: add-project
  params:    
  - name: owner
    value: ${owner}
  - name: type
    value: ${type}
  - name: repo-name
    value: ${repoName}
  - name: webhooks
    value: |
      http://branch-push.${namespace}:8080 '*' push
      http://gitea-chat.${namespace}:8080 '*' issue_comment
  - name: git-server-http
    value: ${gitServerHttp}
  workspaces:
  - name: gitea-user-token
    secret:
      SecretName: gitea-user-token
EOF