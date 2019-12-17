#                    ChannelInboundHandlerAdapter生命周期详解

## 记一段代码

```java
package com.im.server.handler;

import com.im.protocol.packet.request.LoginRequestPacket;
import com.im.protocol.packet.response.LoginResponsePacket;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.SimpleChannelInboundHandler;

/**
 * @program: im-netty->LoginRequestHandler
 * @description: 登录的消息处理器
 * @author: huangfu
 * @date: 2019/12/3 15:40
 **/
public class LoginRequestHandler extends SimpleChannelInboundHandler<LoginRequestPacket> {
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, LoginRequestPacket loginRequestPacket) throws Exception {
        System.out.println(System.currentTimeMillis()+"-----------收到客户端的登录请求-----------" );

        LoginResponsePacket loginResponsePacket = new LoginResponsePacket();
        loginResponsePacket.setVersion(loginRequestPacket.getVersion());
        //登录校验
        if (valid(loginRequestPacket)) {
            loginResponsePacket.setSuccess(true);
        }else{
            loginResponsePacket.setReason("账号密码校验失败");
            loginResponsePacket.setSuccess(false);
        }
        //编码
        //登录响应
        ctx.channel().writeAndFlush(loginResponsePacket);
    }
    private boolean valid(LoginRequestPacket loginRequestPacket) {
        return true;
    }

    @Override
    public void handlerAdded(ChannelHandlerContext ctx) throws Exception {
        System.out.println("逻辑处理器被添加：handlerAdded()");
        super.handlerAdded(ctx);
    }

    @Override
    public void channelRegistered(ChannelHandlerContext ctx) throws Exception {
        System.out.println("channel 绑定到线程(NioEventLoop)：channelRegistered()");
        super.channelRegistered(ctx);
    }

    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        System.out.println("channel 准备就绪：channelActive()");
        super.channelActive(ctx);
    }

    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        System.out.println("channel 有数据可读：channelRead()");
        super.channelRead(ctx, msg);
    }

    @Override
    public void channelReadComplete(ChannelHandlerContext ctx) throws Exception {
        System.out.println("channel 某次数据读完：channelReadComplete()");
        super.channelReadComplete(ctx);
    }

    @Override
    public void channelInactive(ChannelHandlerContext ctx) throws Exception {
        System.out.println("channel 被关闭：channelInactive()");
        super.channelInactive(ctx);
    }

    @Override
    public void channelUnregistered(ChannelHandlerContext ctx) throws Exception {
        System.out.println("channel 取消线程(NioEventLoop) 的绑定: channelUnregistered()");
        super.channelUnregistered(ctx);
    }

    @Override
    public void handlerRemoved(ChannelHandlerContext ctx) throws Exception {
        System.out.println("逻辑处理器被移除：handlerRemoved()");
        super.handlerRemoved(ctx);
    }
}

```

## 二、周期函数的的详解

### 1.调用顺序

先看下这段代码的执行结果

> 1576549252385: 端口[8888]绑定成功!
> `逻辑处理器被添加：handlerAdded()`
> `channel 绑定到线程(NioEventLoop)：channelRegistered()`
> `channel 准备就绪：channelActive()`
> `channel 有数据可读：channelRead()`
> 1576549271174-----------收到客户端的登录请求-----------
> 1576549271534-----------登录成功-----------
> `channel 某次数据读完：channelReadComplete()`

当客户端被关闭后

>`channel 被关闭：channelInactive()`
>`channel 取消线程(NioEventLoop) 的绑定: channelUnregistered()`
>`逻辑处理器被移除：handlerRemoved()`

从上面高亮的顺序可以看得，本次生命周期的调用顺序为：

`handlerAdded() -> channelRegistered() -> channelActive() -> channelRead() -> channelReadComplete()`

客户端关闭后的回调顺序

`channelInactive()  ->  channelUnregistered()  ->  handlerRemoved()`

### 2.每个回调方法的含义

> handlerAdded()

指的是当检测到新连接之后，调用 `ch.pipeline().addLast(new LifeCyCleTestHandler());` 之后的回调，表示在当前的 channel 中，已经成功添加了一个 handler 处理器。也就是一点处理方法被添加到通道中就会回调此方法！

> channelRegistered()

这个回调方法，表示当前的 channel 的所有的逻辑处理已经和某个 NIO 线程建立了绑定关系，类似BIO 编程中，accept 到新的连接，然后创建一个线程来处理这条连接的读写，只不过 Netty 里面是使用了线程池的方式，只需要从线程池里面去抓一个线程绑定在这个 channel 上即可，这里的 NIO 线程通常指的是 `NioEventLoop`,不理解没关系，后面我们还会讲到。

> channelActive()

当 channel 的所有的业务逻辑链准备完毕（也就是说 channel 的 pipeline 中已经添加完所有的 handler）以及绑定好一个 NIO 线程之后，这条连接算是真正激活了，接下来就会回调到此方法。

> channelRead()

客户端向服务端发来数据，每次都会回调此方法，表示有数据可读。

> channelReadComplete()

服务端每次读完一次完整的数据之后，回调该方法，表示数据读取完毕。

> channelInactive()

表面这条连接已经被关闭了，这条连接在 TCP 层面已经不再是 ESTABLISH (建立)状态了

> channelUnregistered()

既然连接已经被关闭，那么与这条连接绑定的线程就不需要对这条连接负责了，这个回调就表明与这条连接对应的 NIO 线程移除掉对这条连接的处理

> handlerRemoved()

最后，我们给这条连接上添加的所有的业务逻辑处理器都给移除掉。

![](../image/1666fdc2bdcf3f9e)