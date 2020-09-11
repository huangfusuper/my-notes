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

## 基本使用

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

docker run -it --rm centos bash

-it 提供交互界面
--rm 退出后删除容器
bash 进入容器的后台
-v 宿主机地址:容器地址  数据卷  做持久化操作的，将宿主机和容器的文件映射
-d 守护线程运行
```

> 删除容器

```shell
docker container rm -f myos
```

>删除虚悬镜像

```bash
docker image prune
```

> 删除所有的停止的容器

```bash
sudo docker container prune
```



>删除镜像

```bash
docker rmi -f myos
```

`容器和镜像是不一样的   容器更像对象  镜像是生成容器的东西`

> 进入运行中的容器镜像

```shell
docker exec -it id bash
```

> 定制Dockerfile

```bash
FROM tomcat
WORKDIR /usr/local/tomcat/webapps/ROOT/
RUN rm -rf *
COPY 当前目录的文件 镜像文件目录(以工作目录为相对路径)

FROM:指定基础镜像
WORKDIR：指定工作目录  就是bash进的那个
RUN:后面根的是控制台的命令
COPY:复制
ADD:COPY的增强版自动解压tar包
```

> 定制镜像

```bash
docker build -t 标签名（自定） .
```





```shell
docker run -d -p 9999:80 --name nginx-docker-web -v /docker_local/docker_nginx/www/html/:/usr/share/nginx/html -v /docker_local/docker_nginx/conf/nginx.conf:/etc/nginx/nginx.conf -v /docker_local/docker_nginx/logs/:/var/log/nginx -v /docker_local/docker_nginx/conf.d/:/etc/nginx/conf.d/ nginx
```

