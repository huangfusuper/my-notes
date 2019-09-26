# 一、Lcn案例编写

>一、上个文章里面已经启动了事务协调者  现在我们来开发一个demo来测试一下协调者是否生效了吧！

## 一、编写数据库

>分别在两个不同的库中创建两张表

```sql
CREATE DATABASE /*!32312 IF NOT EXISTS*/`server1` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin */;

USE `server1`;

SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for server1
-- ----------------------------
DROP TABLE IF EXISTS `server1`;
CREATE TABLE `server1`  (
  `id` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

SET FOREIGN_KEY_CHECKS = 1;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;


CREATE DATABASE /*!32312 IF NOT EXISTS*/`server2` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin */;

USE `server2`;
-- ----------------------------
-- Table structure for server2
-- ----------------------------
DROP TABLE IF EXISTS `server2`;
CREATE TABLE `server2`  (
  `id` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

SET FOREIGN_KEY_CHECKS = 1;
```



## 二、Eureka编写

> pom文件

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <parent>
        <artifactId>lcn-test</artifactId>
        <groupId>com.lcn</groupId>
        <version>1.0-SNAPSHOT</version>
    </parent>
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.lcn</groupId>
    <artifactId>eureka</artifactId>


    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-netflix-eureka-server</artifactId>
        </dependency>
    </dependencies>

</project>
```

> 配置文件  application.yml

```yaml
server:
  port: 8761
spring:
  application:
    name: eureka-server

eureka:
  server:
    peer-eureka-nodes-update-interval-ms: 60000
    enable-self-preservation: false
    eviction-interval-timer-in-ms: 5000
  client:
    service-url:
      defaultZone: http://localhost:8761/eureka/
    register-with-eureka: false
    fetch-registry: true


```

> 启动类

```java
package com.eureka.server;

import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;

/**
 * @author huangfu
 */
@SpringBootApplication
@EnableEurekaServer
public class EurekaServer {
    public static void main(String[] args) {
        new SpringApplicationBuilder(EurekaServer.class).run(args);
    }
}

```

## 三、创建公共资源 module(public-resources)

> 创建serve1实体类

```java
package com.pojo;

import lombok.Data;

/**
 * @author huangfu
 */
@Data
public class ServerOne {
    private String id;
    private String name;

    public ServerOne() {
    }

    public ServerOne(String id, String name) {
        this.id = id;
        this.name = name;
    }
}
```

> 创建server2

```java
package com.pojo;

import lombok.Data;

/**
 * @author huangfu
 */
@Data
public class ServerTwo {
    private String id;
    private String name;

    public ServerTwo() {
    }

    public ServerTwo(String id, String name) {
        this.id = id;
        this.name = name;
    }
}

```

