srcRootPath=$1

function cpResoruces() {
  local type=$1
  local length=$(( ${#type} + 1 ))
  local path=$2
  for f in ${type}-*.yaml; do
    cp ${f} ${path}/${f:${length}}
  done
}

commonPath=${srcRootPath}/common
if test ! -d ${commonPath} && mkdir ${commonPath}; then
  cpResoruces common ${commonPath}
fi
