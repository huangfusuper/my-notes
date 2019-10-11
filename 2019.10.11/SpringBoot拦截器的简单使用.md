# SpringBoot过滤器的简单使用

**Filter是Servlet的加强版，能够在请求前后进行处理！可以使请求在执行资源前预先处理数据，也可以在处理资源后进行处理！**

## 一、SpringBoot使用Servlet Filter

> filter是依赖于Servlet容器的，所以在SpringBoot使用Filter的时候也需要实现javax.servlet.Filter

## 二、项目演示

### pom文件

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.filter</groupId>
    <artifactId>test-filter</artifactId>
    <version>1.0-SNAPSHOT</version>



    <!-- Inherit defaults from Spring Boot -->
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.1.8.RELEASE</version>
    </parent>


    <dependencies>
        <!--springboot-web启动-->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <!--springboot aop支持-->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-aop</artifactId>
        </dependency>
    </dependencies>


    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```



```java
package com.demo.filter;

import org.springframework.stereotype.Component;

import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import java.io.IOException;

/**
 * 自定义拦截器
 * @author huangfu
 */
@Component
@WebFilter(filterName = "MyFilter",urlPatterns = {"/*"})
public class MyFilter implements Filter {
    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
        System.out.println("-----------------执行过滤器---------------------");
        filterChain.doFilter(servletRequest,servletResponse);
    }
}

```

> ```java
> @WebFilter(filterName = "MyFilter",urlPatterns = {"/*"})
> ```
>
> ***`filterName`***:指定过滤器的名字
>
> ***`urlPatterns`***:指定拦截的路径 *匹配全部

## 三、多个过滤器的顺序问题

单项目中出现多个过滤器的情况下，如果对顺序有严格的要求，我们可以手动指定顺序大小

>***`@Order(int level)`***:数值越小，越优先执行！

**过滤器1开发**

```java
package com.demo.filter;

import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import java.io.IOException;

/**
 * 自定义拦截器
 * @author huangfu
 */
@Component
@WebFilter(filterName = "MyFilter",urlPatterns = {"/*"})
@Order(1)
public class MyFilter implements Filter {
    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
        System.out.println("-----------------执行过滤器1---------------------");
        filterChain.doFilter(servletRequest,servletResponse);
    }
}

```

**过滤器2开发**

```java
package com.demo.filter;


import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import java.io.IOException;

/**
 * @author huangfu
 */
@Component
@WebFilter(filterName = "MyFilter2",urlPatterns = {"/*"})
@Order(2)
public class MyFilter2 implements Filter {
    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
        System.out.println("-----------执行过滤器2----------------");
        filterChain.doFilter(servletRequest,servletResponse);
    }
}

```

> **结果：过滤器1优先执行**