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

NIO底层在JDK1.4版本是用linux的内核函数select()或poll()来实现，跟上面的NioServer代码类似，selector每次都会轮询所有的sockchannel看下哪个channel有读写事件，有的话就处理，没有就继续遍历，JDK1.5开始引入了epoll基于事件响应机制来优化NIO，首先我们会将我们的SocketChannel注册到对应的选择器上并选择关注的事件，后续操作系统会根据我们设置的感兴趣的事件将完成的事件SocketChannel放回到选择器中，等待用户的处理！那么它能够解决上述的问题吗？

肯定是可以的，因为**上面的一个同步非阻塞I/O痛点在于CPU总是在做很多无用的轮询**，在这个模型里被解决了！这个模型从selector中获取到的Channel全部是就绪的，后续只需要也就是说他**每次轮询都不会做无用功！**

##### 深入 底层概念解析

###### select模型

如果要深入分析NIO的底层我们需要逐步的分析，首先，我们需要了解一种叫做select()函数的模型，它是什么呢？他也是NIO所使用的多路复用的模型之一，是JDK1.4的时候所使用的一种模型，他是epoll模型之前所普遍使用的一种模型，他的效率不高，但是当时被普遍使用，后来才会被人优化为epoll！

他是如何做到多路复用的呢？如图：


1. 首先我们需要了解操作系统有一个叫做工作队列的概念，由CPU轮流执行工作队列里面的进程，我们平时书写的Socket服务端客户端程序也是存在于工作队列的进程中，只要它存在于工作队列，它就会被CPU调用执行！我们下文将该网络程序称之为**进程A**

![image-20210310223623730](http://images.huangfusuper.cn/typora/image-20210310223623730.png)

2. 他的内部会维护一个 Socket列表，当调用系统函数select(socket[])的时候，操作系统会将**进程A**加入到Socket列表中的每一个Socket的等待队列中，同时将**进程A**从工作队列移除，此时，**进程A**处于阻塞状态！
	![image-20210310223709483](http://images.huangfusuper.cn/typora/image-20210310223709483.png)

3. 当网卡接收到数据之后，触发操作系统的中断程序，根据该程序的Socket端口取对应的Socket列表中寻找该**进程A**，并将**进程A**从所有的Socket列表中的等待队列移除，并加入到操作系统的工作队列！

	![image-20210310223932406](http://images.huangfusuper.cn/typora/image-20210310223932406.png)

4. 此时进程A被唤醒，此时知道至少有一个Socket存在数据，开始依次遍历所有的Socket，寻找存在数据的Socket并进行后续的业务操作

	![image-20210310224109432](http://images.huangfusuper.cn/typora/image-20210310224109432.png)

**该种结构的核心思想是，我先让所有的Socket都持有这个进程A的引用，当操作系统触发Socket中断之后，基于端口寻找到对应的Socket,就能够找到该Socket对应的进程，再基于进程，就能够找到所有被监控的Socket!   要注意，当进程A被唤醒，就证明一件事，操作系统发生了Socket中断，就至少有一个Socket的数据准备就绪，只需要将所有的Socket遍历，就能够找到并处理本次客户端传入的数据！**



但是，你会发现，这种操作极为繁琐，中间似乎存在了很多遍历，先将进程A加入的所有的Socket等待队列需要遍历一次，发生中断之后需要遍历一次Socket列表，将所有对于进程A的引用移除，并将进程A的引用加入到工作队列！因为此时进程A并不知道哪一个Socket是有数据的，所以，由需要再次遍历一遍Socket列表，才能真正的处理数据，整个操作总共遍历了3此Socket，为了保证性能，所以1.4版本种，最多只能监控1024个Socket,去掉标准输出输出和错误输出只剩下1021个，因为如果Socket过多势必造成每次遍历消耗性能极大！

###### epoll模型

epoll总共分为三个比较重要的函数：

1. **epoll_create** 对应JDK NIO代码种的**Selector.open()**
2. **epoll_ctl** 对应JDK NIO代码中的**socketChannel.register(selector,xxxx);**
3. **epoll_wait** 对应JDK NIO代码中的 **selector.select();**

感兴趣的可以下载一个open-jdk-8u的源代码，也可以关注公众号回复openJdk获取源码压缩包！

他是如何优化select的呢？


1. **epoll_create**：这些系统调用将返回一个非负文件描述符，他也和Socket一样，存在一个等待队列，但是，他还存在一个就绪队列！

	![image-20210310231234730](http://images.huangfusuper.cn/typora/image-20210310231234730.png)   

2. **epoll_ctl** ：添加Socket的监视，对应Java中将SocketChannel注册到Selector中，他会将创建的文件描述符的引用添加到Socket的等待队列！这点比较难理解，注意是将**EPFD**（Epoll文件描述符）放到Socket的等待队列！

   ![image-20210310231305931](http://images.huangfusuper.cn/typora/image-20210310231305931111.png)

3. 当操作系统发生中断程序后，基于端口号（客户端的端口号是唯一的）寻找到对应的Socket,获取到**EPFD**的引用，将该Socket的引用加入到**EPFD**的就序列表！

   ![image-20210310232256771](http://images.huangfusuper.cn/typora/image-20210310232256771.png)

4. **epoll_wait**：查看**EPFD**的就绪列表是否存在Socket的引用，如果存在就直接返回，不存在就将进程A加入到**EPFD**的等待队列，并移除进程A再工作队列的引用！

  ![image-20210310231400214](http://images.huangfusuper.cn/typora/image-20210310231400214.png)

  ![image-20210310231425286](http://images.huangfusuper.cn/typora/image-20210310231425286.png)

5. 当网卡再次接收到数据，发生中断，进行上述步骤，将该Socket的因引用加入到就序列表，并唤醒**进程A**，移除该**EPFD**等待队列的进程A，将进程A加入到工作队列，程序继续执行！

   ![image-20210310232111376](http://images.huangfusuper.cn/typora/image-20210310232111376.png)

### 4. 异步非阻塞I/O

异步非阻塞模型是用户应用只需要发出对应的事件，并注册对应的回调函数，由操作系统完成后，回调回调函数，完成具体的约为操作！先看一段代码

```java
public static void main(String[] args) throws Exception {
        final AsynchronousServerSocketChannel serverChannel = AsynchronousServerSocketChannel.open().bind(new InetSocketAddress(9000));
		//监听连接事件，并注册回调
        serverChannel.accept(null, new CompletionHandler<AsynchronousSocketChannel, Object>() {
            @Override
            public void completed(AsynchronousSocketChannel socketChannel, Object attachment) {
                try {
                    System.out.println("2--"+Thread.currentThread().getName());
                    // 再此接收客户端连接，如果不写这行代码后面的客户端连接连不上服务端
                    serverChannel.accept(attachment, this);
                    System.out.println(socketChannel.getRemoteAddress());
                    ByteBuffer buffer = ByteBuffer.allocate(1024);
                    //监听read事件并注册回调
                    socketChannel.read(buffer, buffer, new CompletionHandler<Integer, ByteBuffer>() {
                        @Override
                        public void completed(Integer result, ByteBuffer buffer) {
                            System.out.println("3--"+Thread.currentThread().getName());
                            buffer.flip();
                            System.out.println(new String(buffer.array(), 0, result));
                            //向客户端回写一个数据
                            socketChannel.write(ByteBuffer.wrap("HelloClient".getBytes()));
                        }
						//发生错误调这个
                        @Override
                        public void failed(Throwable exc, ByteBuffer buffer) {
                            exc.printStackTrace();
                        }
                    });
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
			//发生错误调这个
            @Override
            public void failed(Throwable exc, Object attachment) {
                exc.printStackTrace();
            }
        });

        System.out.println("1--"+Thread.currentThread().getName());
        Thread.sleep(Integer.MAX_VALUE);
    }
}
```

AIO客户端

```java
public static void main(String... args) throws Exception {
    AsynchronousSocketChannel socketChannel = AsynchronousSocketChannel.open();
    socketChannel.connect(new InetSocketAddress("127.0.0.1", 9000)).get();
    socketChannel.write(ByteBuffer.wrap("HelloServer".getBytes()));
    ByteBuffer buffer = ByteBuffer.allocate(512);
    Integer len = socketChannel.read(buffer).get();
    if (len != -1) {
        System.out.println("客户端收到信息：" + new String(buffer.array(), 0, len));
    }
}
```

![image-20210310233152285](http://images.huangfusuper.cn/typora/image-20210310233152285.png)

原谅我画图功底，整体逻辑就是，告诉系统我要关注一个连接的事件，如果有连接事件就调用我注册的这个回调函数，回调函数中获取到客户端的连接，然后再次注册一个read请求，告诉系统，如果有可读的数据就调用我注册的这个回调函数！当存在数据的时候，执行read回调，并写出数据！

**为什么Netty使用NIO而不是AIO？**

在Linux系统上，AIO的底层实现仍使用Epoll，没有很好实现AIO，因此在性能上没有明显的优势，而且被JDK封装了一层不容易深度优化，Linux上AIO还不够成熟。Netty是**异步非阻塞**框架，Netty在NIO上做了很多异步的封装。简单来说，现在的AIO实现比较鸡肋！