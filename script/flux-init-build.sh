set -e

# 替换数组元素
# 1.数组元素内容为单行字符串
# 2.模板内,一行仅可指定一数组变量
function a(){
  line=$1

  key=$(echo "'$line'" | sed -r 's/.*\$\{([A-Z_]+)}.*/\1/')

  for v in $(eval echo \${$key}); do
    echo "$line" | sed -r "s/\\$\{[^}]+}/$v/"
  done
}
export -f a

function parse() {
  file=$1
  awk '/\$\{[A-Z_]+}/{gsub("'"'"'","'"'\\\''"'"); L="'\''"$0"'\''"; system("a "L); next} {print}' \
  $file
}

# -------------------------------------------------------------------- #

export BRANCH_TYPE=$1
shift

export MANIFEST_SUFFIX=$1
shift

export WEBHOOK=$1
shift

export ENV="$@"


# 选取需部署的环境
ENV_DIR=env
declare -a envs
for i in $ENV; do
  if grep "^deploy: true$" 1>/dev/null 2>&1 $ENV_DIR/$i/taskrun.yaml; then
    envs+=($i)
  fi
done
export ENV="${envs[@]}"


TEMP_DIR=templates/flux-init

# init
parse $TEMP_DIR/pipeline.yaml

echo ---
echo

# trigger
parse $TEMP_DIR/trigger.yaml

echo ---
echo
