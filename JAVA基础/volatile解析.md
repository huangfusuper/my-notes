# 面试官问我Volatile的原理？从操作系统层面的设计怼回去！

在多线程并发编程中，synchronized和volatile都扮演着及其重要的角色；可以这么说，Volatile是轻量级的synchronized！volatile他在多处理器开发中保证了共享变量的可见性！也能保证在多线程并发情况中指令重排序的情况！

## 什么是可见性？

电脑处理器为了提高运行速度，所以不会直接与内存进行交互！而是先会将数据读取到内部缓存！之后在进行操作，操作完之后满足一定条件之后，才会将内部缓存的数据写进内存！所以，多线程共享变量，可能会存在脏读的现象，也就是，明明已经将数据更改！但是却会出现因为各个处理器内部缓存没有更新，所导致的脏读现象！volatile的存在就是为了解决这个问题！使用了volatile声明的变量会将这个数据在缓存行的数据写入到内存中！同时各个处理器通过嗅探在总线上传播的数据来检查自己的缓存是不是过期了！进而保证数据对于各个线程和处理器的可见性!

## 那么，volatile是如何保证可见性的呢？

我们先看一段代码！

```java
public class TestVolatile{
    public static volatile int value;
    public static void main(String[] args) {
           int a = 10;
           value = 9;
           value += a;
    }
}
```

我们知道，java代码在编译后，会被编译成字节码！最终字节码被类加载器加载到JVM里面！JVM执行字节码最终也需要转换为汇编指令在CPU上运行！那么我们就将这段代码编译为汇编语言，看一下volatile修饰的变量，到底做了什么操作！保证了可见性！

```shell
 0x00007f96b93132ed: lock addl $0x0,(%rsp)     ;*putstatic value
                                                ; - TestVolatile::main@5 (line 6)
```

重点关注`lock addl $0x0,(%rsp)`通过查验 IA-32架构软件开发人员手册 发现，带有lock前缀的的指令在多核处理器会发生两件事：

1. 将当前处理器缓存行的数据写回到系统内存里面去
2. 这个写回内存的操作会使其他CPU缓存行的数据无效

所以说在这个数据进行修改操作的时候，会重新从系统内存中把数据读取到缓存行中！

**volatile的定义：**在java语言规范第三版中对volatile的定义如下，*Java编程语言，允许线程访问共享变量，为了确保共享变量能够被准确和一致的更新，线程应该使用排他锁来单独获取这个变量！*

Lock前缀指令导致在执行指令期间，声言处理器的LOCK#信号。在多处理器环境中，LOCK#信号确保在声言该信号期间，处理器可以独占任何共享内存！

为什么 处理器可以独占任何共享内存呢？

> 因为它会锁住总线，导致其他CUP不能访问总线，不能访问总线就意味着不能访问系统内存！

总线锁定把CPU和内存的通信给锁住了，使得在锁定期间，其他处理器不能操作其他内存地址的数据，从而开销较大，所以后来的CPU都提供了缓存一致性机制，Intel的奔腾486之后就提供了这种优化。

缓存一致性：缓存一致性机制就整体来说，是当某块CPU对缓存中的数据进行操作了之后，就通知其他CPU放弃储存在它们内部的缓存，或者从主内存中重新读取，用MESI阐述原理如下：

MESI协议：是以缓存行(缓存的基本数据单位，在Intel的CPU上一般是64字节)的几个状态来命名的(全名是Modified、Exclusive、 Share or Invalid)。该协议要求在每个缓存行上维护两个状态位，使得每个数据单位可能处于M、E、S和I这四种状态之一，各种状态含义如下：

- M：被修改的。处于这一状态的数据，只在本CPU中有缓存数据，而其他CPU中没有。同时其状态相对于内存中的值来说，是已经被修改的，且没有更新到内存中。

- E：独占的。处于这一状态的数据，只有在本CPU中有缓存，且其数据没有修改，即与内存中一致。
- S：共享的。处于这一状态的数据在多个CPU中都有缓存，且与内存一致。
-  I：无效的。本CPU中的这份缓存已经无效。

​     一个处于M状态的缓存行，必须时刻监听所有试图读取该缓存行对应的主存地址的操作，如果监听到，则必须在此操作执行前把其缓存行中的数据写回CPU。
​        一个处于S状态的缓存行，必须时刻监听使该缓存行无效或者独享该缓存行的请求，如果监听到，则必须把其缓存行状态设置为I。
​        一个处于E状态的缓存行，必须时刻监听其他试图读取该缓存行对应的主存地址的操作，如果监听到，则必须把其缓存行状态设置为S。

​       当CPU需要读取数据时，如果其缓存行的状态是I的，则需要从内存中读取，并把自己状态变成S，如果不是I，则可以直接读取缓存中的值，但在此之前，必须要等待其他CPU的监听结果，如其他CPU也有该数据的缓存且状态是M，则需要等待其把缓存更新到内存之后，再读取。

​       当CPU需要写数据时，只有在其缓存行是M或者E的时候才能执行，否则需要发出特殊的RFO指令(Read Or Ownership，这是一种总线事务)，通知其他CPU置缓存无效(I)，这种情况下性能开销是相对较大的。在写入完成后，修改其缓存状态为M。

​       所以如果一个变量在某段时间只被一个线程频繁地修改，则使用其内部缓存就完全可以办到，不涉及到总线事务，如果缓存一会被这个CPU独占、一会被那个CPU 独占，这时才会不断产生RFO指令影响到并发性能。

> 其实JDK7的并发包中，著名的并发编程大师，Doug lea 新增了一个队列集合 Linked-TransferQueue 他用了一种特殊的方式优化了volatile,是一种追加字节的方式！我们以后可能会出一个详解的，想要探究他，就一定要探究到处理器的硬件配置！我们有时间再说！

## 关于可见性的一个小案例

```java
public class NoVisibility {
    private static boolean ready;
    private static class ReaderThread extends Thread{
        public void run(){
            while (!ready) {
                System.out.println(3);
            }
            System.out.println("-------------我是咋执行的？？-----------------");
        }
    }
    public static void main(String args[]) throws Exception{
        new ReaderThread().start();
        ready=true;
    }
}
```

对于上面的一个代码，正常情况下，他应该一直输出3，但是如果发生脏读的情况！也就是缓存行的数据没有更新，那么有可能执行这个代码:

```java
System.out.println("-------------我是咋执行的？？-----------------");
```

## 什么是指令重排序

> 在执行程序时，为了提高性能，编译器和处理器常常会对指令做重排序。

![img](../image/4222138-0531c2c33ca2f3d2.webp)

1. 编译器优化的重排序。编译器在不改变单线程程序语义的前提下，可以重新安排语句的执行顺序。

2. 指令级并行的重排序。现代处理器采用了指令级并行技术（Instruction-LevelParallelism，ILP）来将多条指令重叠执行。如果不存在数据依赖性，处理器可以改变语句对应机器指令的执行顺序。

3. 内存系统的重排序。由于处理器使用缓存和读/写缓冲区，这使得加载和存储操作看上去可能是在乱序执行。

## volatile是如何防止指令重排序的？

从汇编语言中可以看到在对volatile变量赋值后会加一条`lock addl $0x0,(%rsp)`指令;lock指令具有内存屏障的作用，lock前后的指令不会重排序;

> **内存屏障：**CPU术语定义是一组处理器指令，用于实现对内存操作的顺序限制！

在hotspot源码中内存屏障也是使用这样的指令实现的，没使用mfence指令，hotspot中解释说mfence有时候开销会很大。

内存屏障的功能，java解释器遇到volatile变量，会在volatile变量赋值之后，加一个lock addl $0x0,(%rsp)具有内存屏障功能的指令，防止内存重排序。

可能咋这么说不太好理解，我们举个例子来说明一下：

```java
package com.zanzan.test;

public class TestVolatile {
    int a = 0;
    boolean flag = false;

    public void testA(){
        //语句1
        a = 1;
        //语句2
        flag = true;
    }

    public void testB(){
        if (flag){
            a = a + 5;
            System.out.println(a);
        }
    }

    public static void main(String[] args) {
        TestVolatile testVolatile = new TestVolatile();
        new Thread(new Runnable() {
            @Override
            public void run() {
                testVolatile.testA();
            }
        },"testVolatileA").start();

        new Thread(new Runnable() {
            @Override
            public void run() {
                testVolatile.testB();
            }
        },"testVolatileB").start();
    }

}
```

正常情况下结果是:6

但是发生指令重排后，语句2先执行，执行后线程时间片切换；线程2执行testB（），此时a = 0 那么此时结果为 ：5

这就是指令重排序！

我们使用 `volatile`就可以解决：如何解决呢？

```java
volatile boolean  flag = false;
volatile int a = 0;
```

