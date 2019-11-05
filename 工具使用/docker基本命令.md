# docker基本命令

## docker安装

>1.查看内核版本

```shell
uname -r
```

> 2.安装所需要的工具

```shell
yum install -y yum-utils device-mapper-persistent-data lvm2
```

> 查看 device-mapper-persistent-data和lvm2是否安装

```shell
rpm -qa|grep device-mapper-persistent-data
rpm -qa|grep lvm2
```

> 安装 yum源

```shell
yum-config-manager --add-repo https://download.doker.com/linux/centos/docker-ce.repo
```

> 刷新yum源

```shell
yum makecache fast
```

> 查看docker版本

```shell
yum list docker-ce.x86_64 --showduplicates | sort -r
```

> 安装最新版docker

```shell
yum install docker-ce -y
```

> 查看 docker版本

```shell
docker version
```

> 启动 docker

```she
systemctl start docker
```

> 查看所有镜像

```shell
docker image list
```

> 查看镜像状态

```shell
docker container ls
```

> 搜索镜像

```java
docker search xxx
```

> 拉取镜像

```shell
docker pull centos
```

> 运行镜像

```shell
docker run --name myos -d centos
```

> 删除镜像

```shell
docker container rm -f myos
```

> 另一种运行镜像的方式

```shell
docker run --name myos -it -d centos
```

> 进入容器镜像

```shell
docker exec -it myos /bin/bash
```

