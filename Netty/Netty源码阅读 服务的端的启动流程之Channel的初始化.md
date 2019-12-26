# Netty源码阅读服务端的启动流程之服务器Channel的初始化

## 一、启动的步骤

1. 创建服务器Channel
2. `初始化服务器channel`
3. 注册selector
4. 端口绑定

## 二、初始化服务器channel

依旧是从bind入口

>io.netty.bootstrap.AbstractBootstrap#bind(int) 
>
>​		io.netty.bootstrap.AbstractBootstrap#bind(java.net.SocketAddress) 
>
>​				io.netty.bootstrap.AbstractBootstrap#doBind
>
>​						io.netty.bootstrap.AbstractBootstrap#initAndRegister
>
>​								io.netty.bootstrap.AbstractBootstrap#init
>
>​										`io.netty.bootstrap.ServerBootstrap#init`

以下是简化代码

```java
final Map<ChannelOption<?>, Object> options = options0();
synchronized (options) {
    channel.config().setOptions(options);
}
```

将用户自己写的配置set进channel的配置文件

```java
final Map<AttributeKey<?>, Object> attrs = attrs0();
synchronized (attrs) {
    for (Entry<AttributeKey<?>, Object> e: attrs.entrySet()) {
        @SuppressWarnings("unchecked")
        AttributeKey<Object> key = (AttributeKey<Object>) e.getKey();
        channel.attr(key).set(e.getValue());
    }
}
```

将用户自己搞的值放进配置文件

```java
p.addLast(new ChannelInitializer<Channel>() {
    @Override
    public void initChannel(Channel ch) throws Exception {
        final ChannelPipeline pipeline = ch.pipeline();
        ChannelHandler handler = config.handler();
        if (handler != null) {
            pipeline.addLast(handler);
        }
    }
});
```

将自定义的处理器

```java
.handler(new ChannelInboundHandlerAdapter(){})
```

添加到对应的管道流对象，回想一下 pipeline是什么时候被创建的？是在创建channel的时候被创建的对吧！创建channel的最后一步就是创建  id unsafe 和pipeline 所以pipeline是在哪个时候被创建的！

```java
ch.eventLoop().execute(new Runnable() {
    @Override
    public void run() {
        pipeline.addLast(new ServerBootstrapAcceptor(
            currentChildGroup, currentChildHandler, currentChildOptions, currentChildAttrs));
    }
});
```

保存一些用户的参数至此Channel的初始化完成