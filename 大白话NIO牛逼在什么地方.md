## 前言

距离上一次发布文章将近半年左右了，具体为什么停更，说实话一部分原因是去年10月1放假之后我玩疯了....另外一部原因是总感觉文章写到一定地步之后，我有点不知道写什么了，去年主要更新的是Spring源码系列的文章，我的主要精力也放在了Spring相关源码的研究上，Spring源码系列的文章，到现在为止，大体也告一段落了，后续是准备出一版关于Netty相关的系列文章，过年的时候着重研究了下！上个图：

![<u>image-20210310124028790</u>](http://images.huangfusuper.cn/typora/image-20210310124028790.png)

后续会慢慢更新！我们回归正题！

## 一、为什么必须去了解NIO

首先你需要之后Netty的主要实现手段就是Nio,很多人一直学不明白Netty，根本原因是 除了日常开发中很难能够实践，很大一部分原因是不熟悉NIO，事实上真正熟悉了NIO和它背后的原理之后，去查看Netty的源码就有如神助！我们今天就从最基本的IO、以及NIO学起！

## 二、操作系统是如何定义I/O的

**I/O**相关的操作，详细各位从事java的人员并不陌生，顾名思义也就是**Input/Output**,对应着连个动词，**Read/Write** 读写两个动作，但是在上层系统应用中无论是读还是写，**操作系统都不会直接的操作物理机磁盘数据**，而是由系统内核加载磁盘数据！我们以Read为例，当程序中发起了一个Read请求后，操作系统会将数据从内核缓冲区加载到用户缓冲区，如果内核缓冲区内没有数据，内核会将该次读请求追加到请求队列，当内核将磁盘数据读取到内核缓冲区后，再次执行读请求，将内核缓冲区的数据复制到用户缓冲区，继而返回给上层应用系统！

![](http://images.huangfusuper.cn/typora/%E4%B8%AD%E6%96%AD%E8%AF%BB%E5%8F%96%E6%96%87%E4%BB%B6.png)

write请求也是类似于上图的情况，用户进程写入到用户缓冲区，复制到内核缓冲区，然后当数据到达一定量级之后由内核写入到网口或者磁盘文件！

假设我们以Socket服务端为例，我们口述一下一个完整的读写操作的流程：

1. 客户端发送一个数据到网卡，由操作系统内核将数据复制到内核缓冲区！
2. 当用户进程发起**read**请求后，将数据从内核缓冲区复制到用户缓冲区！
3. 用户缓冲区获取到数据之后程序开始进行业务处理！处理完成后，调用Write请求，将数据从用户缓冲区写入到内核缓冲区！
4. 系统内核将数据从内核缓冲区写入到网卡，通过底层的通讯协议发送到客户端！

## 三、网络编程中的IO模型

本文旨在让初学者先大致了解一下基本原理，所以这里并不会涉及到太多代码，具体的实现逻辑，可以关注后续源码分析的时候的文章，这里只做一个铺垫，为日后的学习做一个比较好的铺垫！

### 1. 同步阻塞I/O

#### I. 传统的阻塞IO模型

![](http://images.huangfusuper.cn/typora/202103101408.png)

这种模型是单线程应用，服务端监听客户端连接，当监听到客户端的连接后立即去做业务逻辑的处理，**该次请求没有处理完成之前**，服务端接收到的其他连接**全部阻塞不可操作**！当然开发中，我们也不会这样写，这种写法只会存在于协议demo中！这种写法的缺陷在哪呢？

我们看图发现，当一个新连接被接入后，其他客户端的连接全部处于阻塞状态，那么当该客户端处理客户端时间过长的时候，会导致阻塞的客户端连接越来越多导致系统崩溃，我们是否能够找到一个办法，**使其能够将业务处理与Accept接收新连接分离开来**！这样业务处理不影响新连接接入就能够解决该问题！

#### II. 伪异步阻塞IO模型

![](http://images.huangfusuper.cn/typora/202103101441.png)

这种业务模型是是对上一步单线程模型的一种优化，当一个新连接接入后，获取到这个链接的**Socket**,交给一条新的线程去处理，主程序继续接收下一个新连接，这样就能够解决同一时间只能处理一个新连接的问题，但是，明眼人都能看出来，这样有一个很致命的问题，这种模型处理小并发短时间可能不会出现问题，但是假设有10w连接接入，我需要开启10w个线程，这样会把系统直接压崩！我们需要**限制线程的数量**，那么肯定就会想到**线程池**，我们来优化一下这个模型吧！

#### III. 优化伪异步阻塞IO模型

![](http://images.huangfusuper.cn/typora/202103101551112.png)

这个模型是JDK1.4之前，没有NIO的时候的一个经典Socket模型，服务端接收到客户端新连接会后，将Socket连接以及业务逻辑包装为任务提交到线程池，由线程池开始执行，同时服务端继续接收新连接！这样能够解决上一步因为线程爆炸所引发的问题，但是我们回想下线程池的的提交步骤：**当核心线程池满了之后会将任务放置到队列，当队列满了之后，会占用最大线程数的数量继续开启线程，当达到最大线程数的时候开始拒绝策略！**  证明我最大的并发数只有1500个，其余的都在队列里面占1024个，假设现在的连接数是1w个，并且使用的是丢弃策略，那么会有近6000的连接任务被丢弃掉，而且1500个线程，线程之间的切换也是一个特别大的开销！这是一个致命的问题！



**上述的三种模型除了有上述的问题之外，还有一个特别致命的问题，他是阻塞的！**  

在哪里阻塞的呢？

- 连接的时候，当没有客户端连接的时候是阻塞的！没有客户端连接的时候，线程只能傻傻的阻塞在哪里等待新连接接入！
- 等待数据写入的时候是阻塞的，当一个新连接接入后但是不写入数据，那么线程会一直等待数据写入，直到数据写入完成后才会停止阻塞！  假设我们使用 **优化后的伪异步线程模型** ，1000个连接可能只有 100个连接会频繁写入数据，剩余900个连接都很少写入，那么就会有900个线程在傻傻等待客户端写入数据，所以，这也是一个很严重的性能开销！

**现在我们总结一下上述模型的问题：**

1. 线程开销浪费严重！
2. 线程间的切换频繁，效率低下！
3. read/write执行的时候会进行阻塞！
4. accept会阻塞等待新连接

**那么，我们是否有一种方案，用很少的线程去管理成千上万的连接，read/write会阻塞进程**，那么就会进入到下面的模型

### 2. 同步非阻塞I/O

同步非阻塞I/O模型就必须使用java NIO来实现了，看一段简单的代码：

```java
public static void main(String[] args) throws IOException {
    //新接连池
    List<SocketChannel> socketChannelList = new ArrayList<>(8);
    //开启服务端Socket
    ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
    serverSocketChannel.bind(new InetSocketAddress(8098));
    //设置为非阻塞
    serverSocketChannel.configureBlocking(false);
    while (true) {
        //探测新连接，由于设置了非阻塞，这里即使没有新连接也不会阻塞，而是直接返回null
        SocketChannel socketChannel = serverSocketChannel.accept();
        //当返回值不为null的时候，证明存在新连接
        if(socketChannel!=null){
            System.out.println("新连接接入");
            //将客户端设置为非阻塞  这样read/write不会阻塞
            socketChannel.configureBlocking(false);
            //将新连接加入到线程池
            socketChannelList.add(socketChannel);
        }
        //迭代器遍历连接池
        Iterator<SocketChannel> iterator = socketChannelList.iterator();
        while (iterator.hasNext()) {
            ByteBuffer byteBuffer = ByteBuffer.allocate(128);
            SocketChannel channel = iterator.next();
            //读取客户端数据 当客户端数据没有写入完成的时候也不会阻塞，长度为0
            int read = channel.read(byteBuffer);

            if(read > 0) {
                //当存在数据的时候打印数据
                System.out.println(new String(byteBuffer.array()));
            }else if(read == -1) {
                //客户端退出的时候删除该连接
                iterator.remove();
                System.out.println("断开连接");
            }
        }
    }
}
```

上述代码我们可以看到一个关键的逻辑：**serverSocketChannel.configureBlocking(false);** 这里被设置为非阻塞的时候无论是 accept还是read/write都不会阻塞！具体的为什么会非阻塞，我放到文章后面说，我们看一下这种的实现逻辑有什么问题！

![](http://images.huangfusuper.cn/typora/202102101755.png)

看这里，我们似乎的确使用了一条线程处理了所有的连接以及读写操作，但是假设我们有10w连接，活跃连接（经常read/write）只有1000，但是我们这个线程需要每次否轮询10w条数据处理，极大的消耗了CPU！

**我们期待什么？ 期待的是，每次轮询值轮询有数据的Channel, 没有数据的就不管他，比如刚刚的例子，只有1000个活跃连接，那么每次就只轮询这1000个，其他的有读写了有数据就轮询，没读写就不轮询！**

### 3. 多路复用模型

多路复用模型是JAVA NIO 推荐使用的经典模型，内部通过 Selector进行事件选择，Selector事件选择通过系统实现，具体流程看一段代码:

```java
public static void main(String[] args) throws IOException {
    //开启服务端Socket
    ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
    serverSocketChannel.bind(new InetSocketAddress(8098));
    //设置为非阻塞
    serverSocketChannel.configureBlocking(false);
    //开启一个选择器
    Selector selector = Selector.open();
    serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);
    while (true) {
        // 阻塞等待需要处理的事件发生
        selector.select();
        // 获取selector中注册的全部事件的 SelectionKey 实例
        Set<SelectionKey> selectionKeys = selector.selectedKeys();
        //获取已经准备完成的key
        Iterator<SelectionKey> iterator = selectionKeys.iterator();
        while (iterator.hasNext()) {
            SelectionKey next = iterator.next();
            //当发现连接事件
            if(next.isAcceptable()) {
                //获取客户端连接
                SocketChannel socketChannel = serverSocketChannel.accept();
                //设置非阻塞
                socketChannel.configureBlocking(false);
                //将该客户端连接注册进选择器 并关注读事件
                socketChannel.register(selector, SelectionKey.OP_READ);
                //如果是读事件
            }else if(next.isReadable()){
                ByteBuffer allocate = ByteBuffer.allocate(128);
                //获取与此key唯一绑定的channel
                SocketChannel channel = (SocketChannel) next.channel();
                //开始读取数据
                int read = channel.read(allocate);
                if(read > 0){
                    System.out.println(new String(allocate.array()));
                }else if(read == -1){
                    System.out.println("断开连接");
                    channel.close();
                }
            }
            //删除这个事件
            iterator.remove();
        }
    }
}
```

相比上面的同步非阻塞IO，这里多了一个selector选择器，能够对关注不同事件的Socket进行注册，后续如果关注的事件满足了条件的话，就将该socket放回到到里面，等待客户端轮询！

![](http://images.huangfusuper.cn/typora/202103101824.png)

### 4. 异步非阻塞I/O



