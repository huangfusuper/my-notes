## 一、基础命令

### 1. 帮助命令

```shell
docker --version		# 显示docker的版本信息
docker info				# 显示docker的系统信息
docker 命令 --help	   # 显示帮助命令
```

### 2. 镜像命令

#### 2.1 搜索镜像

```shell
# 搜索镜像
docker search mysql
# 条件过滤搜索结果
docker search --filter=STARS=5000
```

![image-20200906131527917](http://images.huangfusuper.cn/typora/image-20200906131527917.png)

**列表解释**

- **NAME: 镜像名称**
- **DESCRIPTION: 镜像介绍**
- **STARS: 镜像的stars**
- **OFFICIAL: 是否是官方提供的**
- **AUTOMATED:  是不是自动化的**

#### 2.2 拉取镜像

```shell
# 默认拉取最新的镜像
docker pull mysql
# 指定版本下载
docker pull mysql:5.7
```

#### 2.3 查看所有镜像

```shell
# 查看所有镜像信息
docker images -a
# 查看所有的镜像id
docker images -aq
```

![image-20200906130452865](http://images.huangfusuper.cn/typora/image-20200906130452865.png)

**列表解释**

- **REPOSITORY: 镜像的仓库源**
- **TAG:                镜像的标签**
- **IMAGE ID:       镜像的id**
- **CREATE:          镜像的创建时间**
- **SIZE:                镜像的大小**

2.4 删除镜像

```shell
#删除指定id的镜像
docker rmi 镜像id
docker rmi 镜像id 镜像id 镜像id 镜像id
#删除指定名称的镜像
docker rmi mysql:5.7
#迭代删除所有的镜像
docker rmi -f $(docker images  -aq)
```

### 3. 容器命令

#### 3.1 运行镜像

```shell
docker run [可选参数] image
# 运行实例
docker run --name=mycat -d -p 8080:8080 tomcat
# 用完即删
docker run -it --rm tomcat
# 指定环境变量（实例）
docker run -d --name elasticsearch -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" -e ES_JAVA_OPTS="-Xms64m -Xmx512m"  elasticsearch:7.6.2
```

 **参数说明**
- **--name="Name"：容器名字 tomacat01、tomacat02区分容器**
- -**e**: **指定环境变量**
- **-d：后台守护进程运行**
- **-it：使用交互方式运行，进入容器查看内容**
- **-p：指定容器的端口 -p 8080:8080**
  - **-p ：主机端口：容器端口**
  - **-p ：容器端口**
- **-P：随机指定端口**
- **-v:  指定数据卷**
  - **-v 容器文件位置:宿主机文件位置**
- **--volumes-from: 指定容器的数据卷共享（指定谁，就同步谁的数据！继承！）**
  - **--volumes-from:继承自那个容器**（父容器删除不影响已存在数据）
- **--net: 缺省 bridge**

#### 3.2 进入容器

```shell
# 运行一个centos并进入到容器里面
docker run -it centos /bin/bash
# 退出容器
exit
```

#### 3.3 查看容器

```shell
# 查看正在运行中的容器
docker ps
# 查看所有容器
docker ps -a
```

#### 3.4 退出容器

```shell
exit			# 直接容器停止并退出
Ctrl + P + Q 	# 容器退出不停止
```

#### 3.5 删除容器

```shell
# 删除指定容器
docker rm bde00bc086cf
# 强制删除运行中的容器
docker rm -f bde00bc086cf
# 迭代删除全部的容器
docker rm -f $(docker ps -aq)
```

#### 3.6 容器的启动与停止

```shell
# 启动容器
docker start 容器id
# 重启容器
docker restart 容器id
# 停止容器
docker stop 容器id
# 强制杀死容器
docker kill 容器id
```

#### 3.7 进入当前在正在运行中的命令

```shell
# 进入到指定容器内部进行修改  开启一个新的终端
docker exec -it 0cd4d9d94de2 /bin/bash
# 进入到正在执行中的终端
docker attach 容器id
```

#### 3.8 将文件从容器拷贝到宿主机上

```shell
docker cp 容器id:容器内文件的路径 宿主机路径
#实例
docker cp 0cd4d9d94de2:/Test.java /Test.java
```

#### 3.9 其他常用命令

**查看日志命令**

```shell
# 查看容器运行产生的日志
docker logs -ft --tail 10 容器id
```

**参数解析：**

- **f:  格式化日志**
- **t: 携带日志时间戳**

**查看进程**

```shell
# 查看cpu等信息
docker top 0cd4d9d94de2
# 查看容器元信息
docker inspect 容器id
```

## 二、可视化面板

### 1、安装

```shell
# 安装可视化面板 portainer （数据卷路径不可改变）
docker run -d -p 8088:9000 --restart=always -v /var/run/docker.sock:/var/run/docker.sock --privileged=true portainer/portainer
```

![image-20200906161505532](http://images.huangfusuper.cn/typora/image-20200906161505532.png)

## 三、提交容器为一个镜像

### 1.提交容器

```shell
# 提交一个容器为一个镜像（将容器打包）
docker commit [可选参数] 服务id 自定义镜像名称[:版本标签]
# 示例代码提交
docker commit  -a="huangfu" -m="增加了主页" 19329ae6df90  diytomcat:1.0
```

**参数解释：**

- **-a: 作者**
- **-m: 备注**
- **-c: 将Dockerfile指令应用于创建的映像**
- **-p: 提交期间暂停容器（默认为true）**

## 四、Docker数据卷使用

### 1.数据卷的基本使用

```sh
# 关联数据卷
docker run [可选参数] -v /主机路径/:/容器路径/ 镜像名称
# 关联数据卷的实例命令
docker run -d -p 8080:8080 --name mytomcat -v /home/tomcat/webapps/:/usr/local/tomcat/webapps tomcat
```

### 2.mysql安装实战

```shell
docker run -d -p 3366:3306 -v /home/mysql/conf:/etc/mysql/conf.d -v /home/mysql/data:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=123456 --name mysql01 mysql:5.7
```

**命令解析：**

- **-d: 守护进程运行**
- **-v: 添加数据卷（宿主机位置和容器位置映射）**
- **-p: 堆对外映射端口**
- **-e: 指定环境变量**
- **--name: 容器名称**

## 五、Dockerfile

### 1. 构建镜像文件

```shell
# 创建一个Dockerfile
vim Dockerfile

FROM centos

VOLUME ["volume01","volume02"]

CMD echo "-----end---"
CMD /bin/bash

:x

# 构建docker镜像
# -f dockerfile的路径   
# -t 生成的镜像名称
# . 以当前路径为上下文打包
docker build -f /home/docker-volom/Dockerfile -t huangfu/centos:1.0 .

# 构建基本命令
docker build [OPTIONS] PATH | URL | -
```

### 2. Dockerfile概念

1. 每个保留关键字（指令）都必须是大写字母
2. 执行顺序从上到下
3. `#` 表示注释
4. 每一个指令都会创建提交一个新的镜像层并提交！

### 3. Dockerfile语法浅析

![image-20200906203902072](http://images.huangfusuper.cn/typora/image-20200906203902072.png)

- **FROM: 基础镜像，一切都从这里开始构建**
- **MAINTAINER: 镜像是谁写的，姓名+邮箱**
- **RUN: 镜像构建需要运行的命令**
- **ADD: 添加一个内容，比如需要添加一个tomcat，则需要传递一个压缩包，便于在容器内构建！**
- **WORKDIR: 镜像的工作目录**
- **VOLUME: 挂在的目录**
- **EXPOSE: 暴露端口**
- **CMD: 一个指令，指定这个容器启动的时候要运行的命令**
- **ENTRYPOINT: 指定这个容器启动的时候要运行的命令！可以追加命令！**
- **ONBUILD: 当构建一个被继承的Dockerfile 这个时候就会运行指令，触发命令！**
- **COPY: 类似与ADD，将文件拷贝到镜像中**
- **ENV：构建的时候设置环境变量**

```shell
# 构建一个具有复杂命令行的centos
vim Dockerfile

# 镜像继承自centos
FROM centos
# 作者信息
MAINTAINER huangfu<huangfusuper@163.com>
# 设置环境变量
ENV MYPATH /usr/local
# 设置工作目录
WORKDIR $MYPATH
# 执行命令安装指令
RUN yum -y install vim
RUN yum -y install net-tools
# 暴露端口
EXPOSE 80
# 执行一些指令
CMD echo "-------end------"
CMD echo $MYPATH
CMD /bin/bash

:x

# 构建镜像
docker build -f /home/docker-volom/Dockerfile -t huangfu/diycentos:1.0 .
```

## 六、自定义网络

### 1. 网络模式详解

- **<u>bridge: 桥接网络（默认）</u>**
- <u>**host：和宿主机共享**</u>
- <u>**none：不配置网络**</u>
- <u>**container：容器网络联通**</u>

### 2. 查看所有的网络模式

```shell
# 查看所有的网络模式
docker network ls
```

### 3. 创建自定义的网络

```shell
# 创建一个网络
docker network create [OPTIONS] NETWORK

# 创建一个mynet
# create 创建
# driver 使用的网络模式
# subnet 子网掩码
# gateway 网关
# mynety 自定义的名称
docker netywork create --driver bridge --subnet 192.168.0.0/16 --gateway 192.168.0.1 mynety
```

### 4. 使用自定义网络

```shell
docker run -d --net mynety --name tom01  tomcat
docker run -d --net mynety --name tom02  tomcat

# 进入到tom02
docker exec -it 7d75a637a90b865fe70259bd4e0b3f5c95133dc65693b05abaf078d31a362529 /bin/bash
# 结果是互通的
ping tom01
```

![image-20200906213345122](http://images.huangfusuper.cn/typora/image-20200906213345122.png)

### 5. 容器网络互通

```shell
# 把自定义网络和容器打通    容器一个容器两个ip
# 把不在该网络的容器加入当前网络
docker network connect 自定义网络 容器
```

## 七、打包SpringBoot jar项目

### 1. Dockerfile编写

```shell
FROM java:8

COPY *.jar /app.jar

CMD ["--server.port=8080"]

EXPOSE 8080

ENTRYPOINT ["java","-jar","/app.jar"]
```

### 2. 构建镜像

```shell
mkdir idea

cd idea

# 将 Dockerfile与jar包发送到idea目录
# 构建镜像
docker build -t huangfutest:1.0 .
# 后面运行不说了
```

## 八、Docker Compose

### 1.下载Compose

> 官方镜像

```shell
sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
```

> 安装包授权

```shell
sudo chmod +x /usr/local/bin/docker-compose
```

### 2. 官网项目体验

> 文档地址

https://docs.docker.com/compose/gettingstarted/

> 初级搭建初体验

```shell
 mkdir composetest
 cd composetest
 
 vim app.py
```

> 脚本内容

```python
 
 import time

import redis
from flask import Flask

app = Flask(__name__)
cache = redis.Redis(host='redis', port=6379)

def get_hit_count():
    retries = 5
    while True:
        try:
            return cache.incr('hits')
        except redis.exceptions.ConnectionError as exc:
            if retries == 0:
                raise exc
            retries -= 1
            time.sleep(0.5)

@app.route('/')
def hello():
    count = get_hit_count()
    return 'Hello World! I have been seen {} times.\n'.format(count)
```

```shell
vim requirements.txt
```

> 文件内容

```python
flask
redis
```

```shell
vim Dockerfile
```

> 文件内容

```shell
FROM python:3.7-alpine
WORKDIR /code
ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0
RUN apk add --no-cache gcc musl-dev linux-headers
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt
EXPOSE 5000
COPY . .
CMD ["flask", "run"]
```

```she
vim docker-compose.yml
```

> 文件内容

```yml
version: "3.8"
services:
  web:
    build: .
    ports:
      - "5000:5000"
  redis:
    image: "redis:alpine"
```

> 此时文件结构

![image-20201102145803045](http://images.huangfusuper.cn/typora/image-20201102145803045.png)

> 开始构建服务

```shell
docker-compose up
```

> 测试应用（使用redis当做计数器，点击一次，次数+1）



> 以上步骤总结

- 应用 APP.py
- Dockerfile 应用打包为镜像
- 定义Docker-compose.yml文件（定义整个服务，需要的环境.web、redis）
- 启动 compose 项目