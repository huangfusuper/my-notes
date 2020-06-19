# SpringMVC之请求处理适配器与处理器源码分析

上次的SpringMVC源码分析因为篇幅原因只将请求映射器的源码流程分析完毕，不知道大家对上次的流程分析有什么意见呢？空闲的时候是不是自己追了一遍源码嘞？

先上图：

![](../image/mvc流程图.jpg)

上一篇文章，我将 Handler处理器映射器做了一个很详细流程分析，那么本篇文章会围绕`处理器适配器`、`处理器`两个流程来分析源码！

## 1. 处理器适配器源码解析

上篇文章其实后面也大概说了一下后面的大概逻辑，但是事实上，SpringMVC作为一个优秀的框架，他所考虑的是很全面的，其实在开发一个`Controller`的方法不止只有一个加上`@Controller`一个方式，还有基于接口来实现的，比如实现`Colltroller`接口、实现`HttpRequestHandler`接口等操作，对于不同的处理方式，那么对于不同的处理方式，SpringMVC是如何感知到的呢？因此，在SpringMVC根据请求路径找到对应的对应的映射方法后如何判断这个方法是根据上面三种那种方式创建出来的呢？此时处理器适配器就派上用场了！看一段代码！

```java
// 根据请求路径获取到映射方法的详细信息
mappedHandler = getHandler(processedRequest);
if (mappedHandler == null) {
    noHandlerFound(processedRequest, response);
    return;
}

// 调用处理器适配器，找到该方法对应的处理器
HandlerAdapter ha = getHandlerAdapter(mappedHandler.getHandler());
```

> 我们进入到处理器适配器里面的逻辑去看一下

```java
protected HandlerAdapter getHandlerAdapter(Object handler) throws ServletException {
    if (this.handlerAdapters != null) {
        for (HandlerAdapter adapter : this.handlerAdapters) {
            if (adapter.supports(handler)) {
                return adapter;
            }
        }
    }
    throw new ServletException("No adapter for handler [" + handler +
                               "]: The DispatcherServlet configuration needs to include a HandlerAdapter that 									supports this 				handler");
}
```

- 首先他会循环一个叫做 `handlerAdapters` 的属性，那么这个属性是在哪里set的呢？在spring-webmvc.jar目录下有一个叫做`DisPatcherServlet.properties`的文件，在内部定义了三个处理器，为什么是三个处理器呢？因为上面说了，有三种控制器的编码方式，所以会有三种对应的处理器！

![1592546167426](../image/1592546167426.png)

- 该方法会循环所有的适配器方案，直到直到合适的处理器，返回，否则就会抛出`ServletException`异常！