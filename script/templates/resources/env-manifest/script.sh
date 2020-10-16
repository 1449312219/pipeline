echo $1
echo $2
echo $3
echo $4

repoPath=$1
env=$2

mkdir $repoPath/$env -p

cp ./a $repoPath/$env/ -f
date >> $repoPath/$env/a
