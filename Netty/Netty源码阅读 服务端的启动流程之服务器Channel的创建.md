#                              Netty源码阅读 服务端的启动流程之服务器Channel的创建

## 一、启动的步骤

1. `创建服务器Channel`
2. 初始化服务器channel
3. 注册selector
4. 端口绑定

## 二创建服务器Channel

1.入口，服务端所有的启动入口都在绑定端口的代码内部，所以我们以 bind作为方法的入口

```java
serverBootstrap.bind(8081)
```

io.netty.bootstrap.AbstractBootstrap#doBind ->io.netty.bootstrap.AbstractBootstrap#initAndRegister

这个方法内就是对Channel做的创建操作，我们重点关注

```java
 channel = channelFactory.newChannel();
```

denug跟踪后发现io.netty.channel.ReflectiveChannelFactory#newChannel 他进入了这个类！里面只有一个逻辑，就是反射创建一个对象

```java
@Override
    public T newChannel() {
        try {
            return clazz.newInstance();
        } catch (Throwable t) {
            throw new ChannelException("Unable to create Channel from class " + clazz, t);
        }
    }
```

那么此时，我们需要重点关注到 `clazz`到底是何时传进来的

debug后发现这个class的类型是` class io.netty.channel.socket.nio.NioServerSocketChannel`,这恰巧就是我们在创建ServerBootstrap的时候传入的`NioServerSocketChannel`也就是这一句代码

```java
ServerBootstrap serverBootstrap = new ServerBootstrap()
                .group(boss, work)
                .channel(NioServerSocketChannel.class)
                .childOption(ChannelOption.TCP_NODELAY, true)
                .childAttr(AttributeKey.newInstance("childAttr"), "childAttrValue")
                .handler(new ServerHandler())
```

由此可见，NioServerSocketChannel包装成`ReflectiveChannelFactory`被保存在了`ReflectiveChannelFactory`内同时将包装类保存在`ServerBootstrap`的基类`AbstractBootstrap`

> 那么在 `NioServerSocketChannel`被创建的时候会进行什么样的操作呢？我们不妨去看一下NioServerSocketChannel的构造函数

```java
    public NioServerSocketChannel() {
        this(newSocket(DEFAULT_SELECTOR_PROVIDER));
    }
```

> 看来创建Channel的操作是在newSocket里面进行的

```java
private static ServerSocketChannel newSocket(SelectorProvider provider) {
        try {
            return provider.openServerSocketChannel();
        } catch (IOException e) {
            throw new ChannelException(
                    "Failed to open a server socket.", e);
        }
    }
```

`provider.openServerSocketChannel()`调用了jdk底层创建了一个`java.nio.channels.ServerSocketChannel`对象；

> 我们继续往下看：创建出来之后 一路返回，最终到构造函数后，再次调用自己的另一个有参构造函数将ServerSocketChannel传入进去，我们再看他做了哪些操作

```java
public NioServerSocketChannel(ServerSocketChannel channel) {
    super(null, channel, SelectionKey.OP_ACCEPT);
    config = new NioServerSocketChannelConfig(this, javaChannel().socket());
}
```

追入进去之后，(简化后的代码)

```java
protected AbstractNioChannel(Channel parent, SelectableChannel ch, int readInterestOp) {
    super(parent);
    this.ch = ch;
    this.readInterestOp = readInterestOp;
    try {
        ch.configureBlocking(false);
    } catch (IOException e) {
        throw new ChannelException("Failed to enter non-blocking mode.", e);
    }
}
```

暂时不管，在再往里面追

```java
protected AbstractChannel(Channel parent) {
    this.parent = parent;
    id = newId();
    unsafe = newUnsafe();
    pipeline = newChannelPipeline();
}
```

可以发现最终他创建了三个属性并保存起来！

**id:** ChannelId 全局唯一

**unsafe**:AbstractUnsafe 封装了java底层的socket操作，作为连接netty和java 底层nio的重要桥梁。

**pipeline:** 数据管道

**保存完成后，退出到调用方我们发现**

```java
protected AbstractNioChannel(Channel parent, SelectableChannel ch, int readInterestOp) {
    super(parent);
    this.ch = ch;
    this.readInterestOp = readInterestOp;
    try {
        ch.configureBlocking(false);
    } catch (IOException e) {
        throw new ChannelException("Failed to enter non-blocking mode.", e);
    }
}
```

> ch.configureBlocking(false);

将创建的管道设置成了非阻塞的模式

完成后在此返回到调用方

```java
public NioServerSocketChannel(ServerSocketChannel channel) {
    super(null, channel, SelectionKey.OP_ACCEPT);
    config = new NioServerSocketChannelConfig(this, javaChannel().socket());
}
```

> javaChannel().socket()返回的是已经在super里面保存的通过jdk底层创建的`ServerSocketChannel`

进入到`NioServerSocketChannelConfig`后可以发现他分别保存了 NioServerSocketChannel 和 ServerSocketChannel,并对TCP参数进行一些基础设置；比如设置每次读取的最大字节数等！至此Channel被创建完成！