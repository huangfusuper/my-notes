#                               SpringBoot执行跨域处理

## 一、跨域产生的原因？

首先了解一下一个http链接的的组成部分：`http://www.huangfu.com:8080/hello.html`

- **`http`**:协议名
- **`www`**:子域名
- **`huangfu.com`**:主域名
- **`8080`**:端口号
- **`hello.html`**:请求资源

在一次请求中，不同协议，不同子域名，不同主域名，不同端口号，都会被浏览器认为是跨域了，是不安全的！为什么会这样呢

有个名词叫做`同源策略`，浏览器之后处理同源的请求，这也是为了安全性的考虑！同源策略会阻止javascript脚本与不同域的资源进行交互！同源既是同域！这就是跨域产生的原因！

## 二、非同源限制

1. 无法读取非同源网页的 `Cookie`、`LocalStorage` 和 `IndexedDB`
2. 无法接触非同源网页的 `DOM`
3. 无法向非同源地址发送 `AJAX` 请求

## 三、解决方案

**SpringBoot**为我们提供了很简单的处理方式，大概有三种：

1. 在被访问资源上增加跨域注解(麻烦)
2. 设置拦截器，增加特定请求头，和设置方法（有Bug）
3. 增加Springmvc执行的跨域拦截器（推荐）

### 1.第一种方案

在被访问资源上增加跨域注解：

```java
package com.demo.controller;

import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * @author huangfu
 */
@RestController
@CrossOrigin("*")
public class FilterController {

    @RequestMapping("hello")
    public String hello(){
        return "hello";
    }
}
```

> 我们可以在呗访问的方法或类上增加@CrossOrigin("*")注解

### 2.第二种方案

设置拦截器，增加特定请求头，和设置方法

```java
package com.demo.conf;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig implements WebMvcConfigurer {
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedHeaders("*")
                .allowedMethods("*")
                .allowedOrigins("*")
                .allowCredentials(true)
                .maxAge(20000);
    }

}
```

> 我们可以增加一个配置类，覆盖addCorsMappings方法，为所有请求，添加所有请求头，添加到所有方法（POST,GET,PUT,DELDTE...）,允许携带凭证  Cookie等，预检查请求存活时间！

### 3.第三种方案

增加Springmvc执行的跨域拦截器 `CorsFilter`

```java
package com.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

/**
 * @author huangfu
 */
@SpringBootApplication
public class FilterApplication {

    public static void main(String[] args) {
        SpringApplication.run(FilterApplication.class,args);
    }

    private CorsConfiguration corsConfiguration(){
        CorsConfiguration corsConfiguration = new CorsConfiguration();
        corsConfiguration.addAllowedOrigin("*");
        corsConfiguration.addAllowedHeader("*");
        corsConfiguration.addAllowedMethod("*");
        corsConfiguration.setAllowCredentials(true);
        corsConfiguration.setMaxAge(3600L);
        return corsConfiguration;
    }

    @Bean
    public CorsFilter corsFilter(){
        UrlBasedCorsConfigurationSource source  = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**",corsConfiguration());
        return new CorsFilter(source);
    }
}

```

## 四、第二种的缺陷

`DispatchServlet.doDispatch()`方法是SpringMVC的核心入口方法，分析发现所有的拦截器的`preHandle()`方法的执行都在实际Handler的方法（比如某个API对应的业务方法）之前，其中任意拦截器返回`false`都会跳过后续所有处理过程。而SpringMVC对预检请求的处理则在`PreFlightHandler.handleRequest()`中处理，在整个处理链条中出于后置位。由于预检请求中不带Cookie，因此先被权限拦截器拦截。[引用自这个，点击跳转](https://segmentfault.com/a/1190000010348077#articleHeader2)

由于预检查会优先执行拦截器的preHandler()方法，后执行跨域处理！

当前置拦截器失败后，就不会再执行跨域处理配置，此时返回的没有所需要的请求头信息，所以会出现跨域配置失效的错误！

