pwd=$(pwd)

cd /home/vagrant/share/k8s/flux

cat > ${pwd}/flux.yaml <<EOF
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: flux
spec:
  params:
    - name: apiserver-url
      default: https://kubernetes.default

    - name: git-url
    - name: git-paths
      default: '""'
    - name: webhook
    - name: envs
    - name: namespaces
      default: default
    - name: manifest-gen
      default: "true"
    - name: http-registry

  results:
  - name: ssh-key

  volumes:
  - name: workspace
    emptyDir: {}

  steps:
    - name: init
      image: busybox:1.31
      imagePullPolicy: IfNotPresent
      volumeMounts:
      - name: workspace
        mountPath: /workspace/flux
      script: |
        cd /workspace/flux

        cat > install.sh <<EOF
$(sed -r -e '/.*\$.*/ s/\$/\\$/g' -e '/\\$/ s/\\$/\\\\/' install.sh|awk '{print "        "$0}')
        EOF
        chmod u+x /workspace/flux/install.sh


        mkdir k && cd k
$(for i in $(ls k); do 
    echo "        cat > $i <<EOF"; 
    sed -r -e '/\$/ s/\$/\\$/g' -e '/`/s/`/\\`/g' k/$i | awk '{print "        "$0}';
    echo "        "EOF; 
done)

    - name: fluxctl
      image: 10.1.40.43:5000/fluxctl:1.20.1
      volumeMounts:
      - name: workspace
        mountPath: /workspace/flux
      script: |
        cp /usr/bin/fluxctl /workspace/flux/fluxctl

    - name: openssh
      image: 10.1.40.43:5000/lgatica/openssh-client:latest
      volumeMounts:
      - name: workspace
        mountPath: /workspace/flux
      script: |
        host=\$(params.git-url)
        host=\${host#*@}
        host=\${host%%/*}
        port=\${host#*:}
        host=\${host%%:*}

        ssh-keyscan \${port:+-p \$port} \${host} > /workspace/flux/k/ssh-config.yaml

    - name: flux
      image: lachlanevenson/k8s-kubectl
      imagePullPolicy: IfNotPresent
      volumeMounts:
      - name: workspace
        mountPath: /workspace/flux
      script: |
        url=\$(params.apiserver-url)
        ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        token=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
        namespace=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

        kubectl config set-cluster default --server=\$url --certificate-authority=\$ca
        kubectl config set-credentials default --token=\$token
        kubectl config set-context default --cluster=default --user=default --namespace=\$namespace

        cd /workspace/flux

        function toArrayLength() {
          local i=0
          for value in \$1; do
            i=\$(expr \$i + 1)
          done
          echo \$i
        }
        function toArray() {
          local key=\$1
          local values=\$2
          local i=0
          for value in \$values; do
            eval \$key\$i=\$value
            i=\$(expr \$i + 1)
          done
        }
        size=\$(toArrayLength "\$(params.envs)")
        toArray envs "\$(params.envs)"
        toArray namespaces "\$(params.namespaces)"
        toArray paths "\$(params.git-paths)"


        i=0
        while test \$i -lt \$size; do
          eval env=\\$\$envs\$i
          eval ns=\\$\$namespaces\$i
          eval path=\\$\paths\$i

          ./install.sh \$(params.git-url) \$path  \$(params.webhook) \$env \$ns \
                       \$(params.manifest-gen) \$(params.http-registry) > .logs

          cat .logs
          echo \$env \$(tail -n 1 .logs) >> \$(results.ssh-key.path)

          i=\$(expr \$i + 1)
        done
EOF
