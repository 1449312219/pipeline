set -e

export BRANCH_TYPE=$1
shift

export ENV="$@"

# 替换数组元素
# 1.数组元素内容为单行字符串
# 2.模板内,一行仅可指定一数组变量
function a(){
  line=$1

  key=${line#*\${}
  key=${key%%\}*}

  for v in $(eval echo \${$key}); do
    echo "$line" | sed -r "s/\\$\{[^}]+}/$v/"
  done
}
export -f a

awk '/\${/{system("a '"'"'"$0"'"'"' 1");next} {print}' env/init-template.yaml 

echo ---
