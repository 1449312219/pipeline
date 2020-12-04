Tekton + Gitea + Flux 实现触发升级流水线

###### *版本*
kubernetes: v1.18.0
Tekton: v0.15.2
Gitea: v1.12.2
Flux: v1.20.1


###### *安装*
install.sh \  
--gitServerHttp http://10.1.40.43:30280 \  
--owner root \  
--repoName test1234567890 \  
--repoOwnerToken 2050dd8afac6219f87e956944ae7dd2d1935b906

`默认命名空间:  promotion-pipeline-<owner>-<repoName>`  
`在Gitea内创建仓库: `  
`  1. <owner>/<repoName>`  
`  2. <owner>/<repoName>-manifest`  


###### *概述*

![概述.png](https://raw.githubusercontent.com/1449312219/pipeline/master/general.png)
