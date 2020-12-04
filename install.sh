set -eu
set -o pipefail


#------------- parse params ------------#

args=$(getopt --long gitServerHttp:,\
owner:,type::,repoName:,repoOwnerToken:,robotName::,\
namespace:: -- "" $@)

set -- ${args}
while true; do
  case $1 in
    --gitServerHttp | --owner | --repoName | --repoOwnerToken ) 
      name=${1:2}
      value=$2
      shift 2
      eval ${name}=${value}
      ;;
    --type | --robotName | --namespace )
      name=${1:2}
      shift
      next=$1
      case ${next} in
        --* ) ;;
        * )
          eval ${name}=${next}
          shift
          ;;
      esac
      ;;
    * ) break;;
  esac
done

gitServerHttp=${gitServerHttp}
owner=${owner}
repoName=${repoName}
repoOwnerToken=${repoOwnerToken}
type=${type:-user}
robotName=${robotName:-${owner}-${repoName}-robo}
namespace=${namespace:-promotion-pipeline-${owner}-${repoName}}

#---------------------------------------#


repoStandardName=${owner}-${repoName}
giteaIssueSecret=$(head -n 20 /dev/urandom | md5sum | cut -c 1-32)

kubectl create ns ${namespace}
kubectl="kubectl -n ${namespace}"


# load
$kubectl apply -f ./units
$kubectl apply -f ./init
$kubectl apply -f ./promotion/core
$kubectl apply -f ./promotion


# config (security)
$kubectl create -f ./config -R --dry-run=client -o yaml \
| sed -e "s/\${NAMESPACE}/${namespace}/g" \
      -e "s/\${PROJECT_STANDARD_NAME}/${repoStandardName}/g" \
      -e "s/\${GITEA_USER_TOKEN}/${repoOwnerToken}/g" \
      -e "s/\${GITEA_ISSUE_SECRET}/${giteaIssueSecret}/g" \
| $kubectl apply -f -


# triggers
$kubectl create -f ./triggers --dry-run=client -o yaml \
| sed -e "s/\${ROBOT_NAME}/${robotName}/g" \
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
  - name: robot
    value: ${robotName}
  - name: webhooks
    value: |
      http://el-branch-push.${namespace}:8080 '*' push
      http://el-gitea-chat.${namespace}:8080 '*' issue_comment
  - name: git-server-http
    value: ${gitServerHttp}
  workspaces:
  - name: pipelines
    persistentVolumeClaim:
      claimName: pipeline-all-workspaces-pvc
  - name: add
    configmap:
      name: project-init-resources
  - name: gitea-user-token
    secret:
      SecretName: gitea-user-token
EOF