最近断更了一段时间，因为公司比较忙，周五的时候在公司做了一个关于Netty的分享，后续会总结一下分享出来！

最近一段时间发现经常看到很多人，对Spring源码比较感兴趣，日常开发中，无论你做什么什么项目，大部分都离不开Spring生态的那一套东西，所以很多人对Spring底层源码实现很感兴趣，但是有些从来没有接触过源码的开发者，在看Spring源码的过程中确实及其难受的，为什么，大部分人看源码基本都是debug一点一点去看的，最后发现，越追越离谱，越追越深，到最后都追到JDK源码了，也没有明白是什么意思！

对于学习源码，我的看法是，先去完全的熟悉它的用法，想一下如果让你来实现，你会怎么实现！有了这些想法之后，再去看源码去印证你自己的观点，远比你自己去死扣源码快的多。

而且，我问过一些读者还有同事，我发现有很多人，看源码容易陷入一个误区，就是刚开始看源码就死扣着一个细节不放，非得搞懂，我并不是说这样看源码有什么不对，但是在没有对整个框架有一个全局了解的情况下，不要这样看，你应该先把它的大体框架给搞清楚，在后再分功能一步一步的了解每一个功能项！这样做，首先你对整个框架的架构有了一个模糊的认识，再扣细节的途中有时候即使你不知道这个代码在干什么，你也隐约能猜出来，再通过debug 与自己的猜测相互印证，最终达到事半功倍的效果。当然这个建议只针对刚开始看源码的同学，如果你看的源码很多了，那么你肯定又自己的一套学习方法，可以的话，可以在留言区或者私聊作者一起交流一下！

为了帮助一些萌新们或者想要了解Spring源码的小伙伴，我会把Spring的一些大体逻辑分析一下，细节方面，后续作者也会分享，但是今天这一篇文章，只是为了让你了解整个Spring的骨架！

## 二、架构图例

![Spring生命周期总结](http://images.huangfusuper.cn/typora/Spring生命周期总结.png)

这张图基本的概括了Spring初始化bean的整个生命周期，包括大家大概熟悉的一些生命周期的回调，以及AOP或者很多大神都分析过的Spring解决循环依赖的三级缓存，看不懂没关系，后面作者会带着源码一步一步的分析：

## 三、源码分析

### 1.前期准备

```java
/**
 * spring debug
 * @author huangfu
 */
public class SpringDebug {
	public static void main(String[] args) {
		AnnotationConfigApplicationContext app = new AnnotationConfigApplicationContext(SpringDebugConfig.class);
	}
}
```

上面这一行代码我估计使用过Spring的人都特别熟悉，如果不熟悉，那我劝你先学会使用，再去深究一些源码的底层逻辑！

下面我们看一下，他究竟是如何一步一步的实例化bean,接管bean，然后执行各种生命周期类的！我们先不妨猜测一下，spring再读取这些bean的时候，关于bean的信息一定是存放在了某一个实体上，那么这个实体是什么呢？这个类就是`BeanDefinition`那么他存储了什么东西呢？我们看一下它的子类`AbstractBeanDefinition`感兴趣的小伙伴自己点进去看一下，作者这里只是为了让大家了解什么是`BeanDefinition`：

![image-20200725135718518](http://images.huangfusuper.cn/typora/0742bd呕吼.png)

里面定义这类似与这样的属性值，当然作者做截取了少数属性，它里面的属性远远比这多得多，它的目的就是bean实例化的时候，需要的数据不需要再通过自己去反射获取，而是再Spring初始化的时候全部读取，需要的时候从这里面拿就行，了解了bd的概念之后，我们是否疑惑？他读取之后存放在哪里呢？答案是存放再beanFactory里面，所以Spring初始化的时候肯定会先实现一个bean工厂！进入到`AnnotationConfigApplicationContext`里面，你会发下并没有初始化，在那初始化呢？众所周知，一个类再初始化的时候会先加载父类的构造函数，所以我们需要去看一下它的父类`GenericApplicationContext`:

```java
public GenericApplicationContext() {
    //初始化bean的工厂
    this.beanFactory = new DefaultListableBeanFactory();
}
```

果然不出我所料，它再父类里面创建了bean工厂，工厂有了，我们继续回到`AnnotationConfigApplicationContext`里面往下看：发现它调用了一个this(),说明它调用了自己的空构造方法，所以，我们进入看一下：

```java
public AnnotationConfigApplicationContext() {
    //初始化读取器
    this.reader = new AnnotatedBeanDefinitionReader(this);
    //初始化扫描器
    this.scanner = new ClassPathBeanDefinitionScanner(this);
}
```

**至此我们就可以看对照上面那幅图：初始化的时候bean工厂有了**

![image-20200725140629568](http://images.huangfusuper.cn/typora/0725bnean工厂有了.png)

--------------------------------------

**然后再自己的空构造方法里面有初始化了读取器！**

![image-20200725140742200](http://images.huangfusuper.cn/typora/0725读取器啊读取器.png)

那我们继续回到`AnnotationConfigApplicationContext`构造方法里面：

```java
   /**
	 * 创建一个新的AnnotationConfigApplicationContext，从给定的带注释的类派生bean定义
	 * 并自动刷新上下文。
	 * @param annotatedClasses one or more annotated classes,
	 * e.g. {@link Configuration @Configuration} classes
	 */
	public AnnotationConfigApplicationContext(Class<?>... annotatedClasses) {
		//读取Spring内置的几个的class文件转换为bd  然后初始化bean工厂
		this();
		//这一步就是将配置类Config进行了注册并解析bd
		register(annotatedClasses);
		//这一步是核心，Spring的理解全在这一步，这一步理解了也就可以说将Spring理解了70%
		//内部做一系列的操作如调用bean工厂的后置处理器   实例化类  调用 后置处理器的前置处理   初始化类  调用后置处理器的后置处理 注册事件监听等操作
		//完成一个类从class文件变为bean的生命周期
		refresh();
	}
```

下一步是调用`register`方法，干什么呢？试想一下，有时候我们的自动扫描配置是通过注解`@ComponentScan("com.service")`来配置的，这个类一般在哪？对了，一般实在配置类中的！

```java
@Configuration
@ComponentScan("com.service")
public class SpringDebugConfig {}
```

为了能够知道,我们要扫描那些包下的类，我们就必须先去解析配置类的`BeanDefinition`，这样才能获取后续咱们要解析的包，当然这个方法不光解析了扫描的包，还解析了其他东西，本文不做讲解！

### 2.核心功能

好了，再往下走我们就知道了我们即将要扫描那些包下的类，让他变成bean，那么我们继续向下走，走到`refresh();`这个方法不得了他是整个Springbean初始化的核心方法，了解了它也就能够了解Spring的实例化，回调等一些列的问题，我们进去看看：

进来之后，我们一个方法一个方法的分析做了什么功能，首先是：

#### 1). prepareRefresh();

> 这里是做刷新bean工厂前的一系列赋值操作,主要是为前面创建的Spring工厂很多的属性都是空的，这个方式是为他做一些列的初始化值的操作！

#### 2). obtainFreshBeanFactory()

> 告诉子类刷新内部bean工厂  检测bean工厂是否存在 判断当前的bean工厂是否只刷新过一次，多次报错，返回当前使用的bean工厂,当该步骤为xml时 会新建一个新的工厂并返回

#### 3). prepareBeanFactory(beanFactory);

> 这里是初始化Spring的bean容器，向beanFactory内部注册一些自己本身内置的Bean后置处理器也就是通常说的BeanPostProcessor，这个方法其实也是再初始化工厂！

#### 4). postProcessBeanFactory(beanFactory);

> 允许在上下文子类中对bean工厂进行后处理,作用是在BeanFactory准备工作完成后做一些定制化的处理! 但是注意，你点进去是空方法，空方法以为着什么？意味着Spring的开发者希望调用者自定义扩展时使用！

#### 5). invokeBeanFactoryPostProcessors(beanFactory);

> 其实相信看名字，大部分读者都能够猜出，他的目的是扫描非配置类的bd注册到工厂里面，扫描完成之后，开始执行所有的`BeanFactoryPostProcessors`，这里出现了第一个扩展点，自定义实现`BeanFactoryPostProcessors`的时候，他的回调时机是在Spring读取了全部的`BeanDefinition`之后调用的，具体的使用方法读者自行百度！

#### 6). registerBeanPostProcessors(beanFactory);

> 这里是注册bean的后置处理器 也就是  beanPostProcessor 的实现 还有自己内置的处理器  注意这里并没有调用该处理器，只是将胡处理器注册进来bean工厂! 不知道大家使用过`beanPostProcessor`接口这个扩展点吗？他就是再这个方法里面被注册到Spring工厂里面的，当然注意一下，他只是注册进去了，并没有执行！记住并没有执行！

#### 7). initMessageSource();

> 怎么说呢，这个方法作者并不准备深究，因为他和本篇文章的意图相违背，他的目的是做一个国际化操作也就是 i18n的资源初始化

#### 8).initApplicationEventMulticaster();

> Spring为我们提供了对于事件编程的封装，一般来说事件分为三个角色，`事件广播器`(发布事件)，`事件监听器`(监听事件)，`事件源`（具体的事件信息）三个角色,这个方法的目的就是初始化事件的广播器！

#### 9). onRefresh();

> 这里又是一个扩展点，内部的方法为空，Spring并没有实现它，供调用者实现！

#### 10). registerListeners();

> 注册Spring的事件监听器,上面已经说过了，这里是初始化并且注册事件监听器

#### 11). finishBeanFactoryInitialization(beanFactory);

> 这个方法是一个重点，他是为了实例化所有剩余的（非延迟初始化）单例。我们所说的bean的实例化，注入，解决循环依赖，回调`beanPostProcessor`等操作都是再这里实现的！

#### 12). finishRefresh();

> 最后一步：发布相应的事件。Spring内置的事件

至此我们完成了整个Spring初始化的生命周期骨架，这里作者并没有深究里面的实现，只是给读者搭建了一个架子，帮助读者理清Spring的脉络，里面的填充需要读者自己填充！现在回过头去看那个图，是不是就清晰多了？这里我再把那个图放出来，免得你们再翻上去！

![Spring生命周期总结](http://images.huangfusuper.cn/typora/Spring生命周期总结072511111.png)

好了，今天的文章到这里也就结束了，作者闲暇时间整理了一份资料，大家有兴趣可以领取下！

![](http://images.huangfusuper.cn/typora/架构师资料大放送0725.png)

