# 替换数组元素
# 1.数组元素内容为单行字符串
# 2.模板内,一行仅可指定一数组变量
function __replace(){
  line=$1

  key=$(echo "'$line'" | sed -r 's/.*\$\{([A-Z_]+)}.*/\1/')

  for v in $(eval echo \${$key}); do
    echo "$line" | sed -r "s/\\$\{[^}]+}/$v/"
  done
}
export -f __replace

function parsePlaceHolder() {
  local file=$1
  awk '/\$\{[A-Z_]+}/{gsub("'"'"'","'"'\\\''"'"); L="'\''"$0"'\''"; system("__replace "L); next} {print}' \
  $file
}

function addNamespace() {
  local namespace=${1,,*}
  sed -e "/^metadata:/a\  namespace: ${namespace}" -e "/namespace/d"
}

function printSplit() {
  echo ---
  echo
}
