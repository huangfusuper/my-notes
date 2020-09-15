今天我们大概从以下几点去讲解MyBatis对于Spring的一个扩展思路！

![大纲](http://images.huangfusuper.cn/typora/image-20200914214936905.png)

## 一、FactoryBean是干什么？

首先我们至少要知道一个事情，就是FactoryBean的一个大致结构：

![FactoryBean的大致结构](http://images.huangfusuper.cn/typora/image-20200914203802191.png)

**可以看到，整个 FactoryBean有三个方法：**

- **getObject():** 返回具体创建的真实对象！
- **getObjectType():** 返回创建对象的类型！
- **isSingleton():** 创建的该对象是不是单例对象！

此时，至少我们已经知道了，我们可以通过一个FactoryBean来生产一个对象，可以获取这个对象的类型以及这个对象是不是单例！但是离开了Spring它就什么也不是，那么Spring封装这个东西是干嘛的呢？

### 1. 自定义Spring实例化的bean

**正是因为FactoryBean的存在我们才能够插手或者改变一个Bean的创建过程！**，为什么这么说呢？我举个例子：

就拿大家常用的MyBatis为例，我们都知道MyBatis的使用一般都是使用一个接口，映射一个XML文件，MyBatis内部经过动态代理，动态的为接口生成一个实现类，从而让我们能够通过接口直接调用里面的逻辑！

但是MyBatis通过Spring管理之后，同学们是否疑惑过，我们明明没有使用MyBatis那一套逻辑，仅仅通过一个`@Autowired`注解，就能够直接注入到Service使用，那么MyBatis的动态代理逻辑大概是在哪里做的？

没错就是再FactoryBean里面做的！

![MyBatis使用FactoryBean进行动态代理](http://images.huangfusuper.cn/typora/image-20200914205546676.png)

熟悉MyBatis用法的同学看到这个代码是不是就十分的熟悉了？这一段正是MyBatis通过接口生成动态代理的一段逻辑！那么此时我们至少知道了Spring能够FactoryBean调用 getObject()方法能够创建一个对象，并把对象管理起来！

### 2. 不遵循Spring的生命周期

这个为什么呢？作者的想法是，正是因为Spring的作者想要放权给使用者，让使用者自己实现创建一个bean的逻辑，所以Spring并不会过多的插手该Bean的实例化过程，使得一个Bean的实例化完全又使用者本人去实现！

这个类并不会像其它普通的bean那样再Spring容器初始化的时候就进行实例化，而是会类似于懒加载的一种机制，再获取的时候才会进行创建和返回！至于是不是单例，要取决于isSingleton()方法的返回值！

当然，这个创建出来的bean也会被缓存，AOP等逻辑也会对该类生效，当然这都是后话！

### 3. FactoryBean的总结

相信上述文章看完之后你对Factory会有一个基本的认识，我们总结以下Spring调用它的基本流程！

![FactoryBean的调用流程](http://images.huangfusuper.cn/typora/FactoryBean的调用流程.png)

## 二、自定义扫描器

Spring只是一个项目管理的框架，他也是由JAVA语言编写的，所以它必须遵循JAVA语法的规范！我们能够使用Spring帮助我们管理我们开发过程中的一些类，能够自动注入或者AOP代理等逻辑！

但是我们是否发现，Spring它只能够管理我们指定的包下的类，或者我们手动添加的一些类！而且Spring也没有办法去帮我们扫描一些抽象类或者接口，但是我们有时候因为一些特殊的开发，我们必须要打破Spring原有的扫描过程，比如我们就要Spring帮我们管理一个接口、帮我们扫描一些加了特定注解的类等特殊需求，这个时候，我们就不能够使用Spring为我们提供的扫描逻辑了，需要我们自定义一个扫描逻辑！

### 1. 栗子

举个例子（我们还是以MyBatis为例）：

我们通过上面FactoryBean的学习我们理解了一件事，Spring中MyBatis能够通过`FactoryBean`进行动态代理的创建并返回，但是我们都知道使用jdk动态代理所必须的一个元素：`接口`,因为jdk动态代理就是基于接口来做的！

这些接口从哪里来呢？要知道Spring是不会把接口也扫描的，所以此时就需要我们的自定义扫描器了，我们使用自定义扫描器将接口扫描到，然后通过修改`BeanDefinition`强行指定为FactoryBean类型的bean, 把我们的接口传入进去，然后再将`BeanDefinition`加入bean工厂，此时我们需要的一个必须元素`接口`就有了！

![自定义扫描器结合FactoryBean](http://images.huangfusuper.cn/typora/image-20200914221345511.png)



## 三、ImportBeanDefinitionRegistrar

### 1. 调用时机

`ImportBeanDefinitionRegistrar`也是Spring生命周期中重要的一环，上周我们学到，Spring再执行`BeanFactoryPostProcessor`时，会实现执行系统内置的一个后置处理器---`ConfigurationClassPostProcessor`,它的作用就是扫描项目指定路径下的类，转换成对应的`BeanDefinition`!但是它的作用可不止这一个哦！

它除了有扫描指定包下的类的功能，还有解析`@Import`注解的功能，`ImportBeanDefinitionRegistrar`就是`@Import`中一个比较特殊的类，它会被Spring自动的回调内部的`registerBeanDefinitions()`方法！

那么由此可知它的调用时机再`ConfigurationClassPostProcessor之后`，`剩余其他的所有BeanFactoryPostProcessor之前`！

### 2. 回调方法以及意义

上面我们也说到了，他会回调`registerBeanDefinitions()`方法，那么意义何在呢？如果只是能够进行回调的话，`BeanDefinitionRegistryPostProcessor`也能完成类似的功能，它的特殊之处在于什么呢？我们看一下它的方法签名！

![image-20200914224036880](http://images.huangfusuper.cn/typora/方法签名.png)

我们重点关注第一个参数，他在回调的时候，会将标注`@Import`注解的类的所有的元信息封装成`AnnotationMetadata`类，携带回去！

那么携带回去有什么意义呢？举个例子，依旧以MyBatis为例！

> 我们试想以下，上面我们说呢，我们可以通过自定义扫描器将一个个接口转换成FactoryBean然后交给Spring管理，但是我们要扫描那个包下的类呢？
>
> 使用过Spring整合MyBatis的人都应该知道，我们一般都会再启动类上标注一个注解`@MapperScan`指定Mapper接口的包路径，它的目的就是为了向`registerBeanDefinitions`方法传递扫描的路径，以此完成扫描！

![image-20200914225321751](http://images.huangfusuper.cn/typora/image-20200914225321751.png)

## 四、BeanDefinitionRegistryPostProcessor

### 1. 概念

虽然这个`BeanDefinitionRegistryPostProcessor`上周复习的时候，我做过大量的源码层面的讲解！但是今天依旧要简单说一下！

上周的学习我们知道`BeanDefinitionRegistryPostProcessor`是`BeanFactoryPostProcessor`的子类，他们两个有什么区别吗？

我们要知道，`BeanFactoryPostProcessor`只能够对已经存在的 `BeanDefinition`进行修改，但是没有办法进行添加和删除，但是`BeanDefinitionRegistryPostProcessor`不一样，他对父类进行了扩展，提供了添加和删除的API，我们可以通过该类进行增加和删除bean工厂的`BeanDefinition`!

### 2.举个例子

我们依旧是以MyBatis为例！

我们此时通过自定义扫描器把接口转换成了一个bd，但是我们要如何向Spring工厂添加我们扫描到的Bd呢？就是使用这个`BeanDefinitionRegistryPostProcessor`来进行注册bean定义！

![BeanDefinitionRegistryPostProcessor](http://images.huangfusuper.cn/typora/image-20200914230156140.png)

## 五、MyBatis如何扩展的Spring呢？

### 1. 扩展步骤（初始化步骤）

我相信，通过上面的关键点的讲解，你现在心里应该有了一个差不多的概念！MyBatis扩展Spring的方式大概如下：

1. 首先我们需要在配置类标注一个注解`MapperScan`,并且传入Mapper接口所在包路径！

2. `MapperScan`会通过`@Import`注解向Spring注入一个`MapperScannerRegistrar`类，他是`ImportBeanDefinitionRegistrar`类型的，会被Spring自动回调`registerBeanDefinitions`方法！

3. `MapperScannerRegistrar`的`registerBeanDefinitions`方法会构建一个类型为`MapperScannerConfigurer`的`BeanDefinition` ,他是`BeanDefinitionRegistryPostProcessor`类型的！然后注册进Spring容器里面！

4. Spring生命周期会自动回调`MapperScannerConfigurer`的`postProcessBeanDefinitionRegistry`方法！

5. `postProcessBeanDefinitionRegistry`方法内部创建了一个自定义的扫描器`ClassPathMapperScanner`,扫描你传入的包路径下的所有的接口，并转换为`BeanDefinition` !

6. 获取到所由指定接口的`BeanDefinition`之后，遍历所有的`BeanDefinition`，然后修改他的`BeanClass`为`MapperFactoryBean`类，他是`FactoryBean`类型的！

7. 设置完BeanClass之后，通过`definition.getPropertyValues().add()`方法，传入该`BeanDefinition`代表的接口！

8. 将所有的`BeanDefinition`通过 6、7步骤设置之后，全部注册到bean工厂中！由BeanFactory对这些FactoryBean进行管理，和声明周期的管理！

   

   **注意，此时这些类并没有被实例化，被实例化的是你传入的`FactoryBean`类，真实的类还没有被实例化！**



### 2. 扩展步骤（实例化步骤）

1. 在使用或者获取这些bean的时候，Spring会首先获取你要使用的接口类型！
2. 遍历当前容器内所有的bean逐个对比，当有匹配的直接返回！但是，因为Mapper接口还并没有被实例化！所以并没有找到，所以在遍历到`FactoryBean`的时候，会调用`getObjectType`方法，将返回值与你要使用的接口类型作比对！
3. 当 FactoryBean的返回类型匹配的时候，Spring会调用`FactoryBean`的`getObject`方法将对象创建出来！
4. 创建过程中，通过之前传入的接口，做`jdk动态代理`，完成MyBatis的代理逻辑！
5. 对象创建完成后，通过`isSingleton`方法的返回值判断，如果是单例对象，就将该对象缓存起来！并返回！

**至此，我们完成了整个MyBatis整合Spring的全部过程！**



### 3.源码重点讲解

#### 1）自定义扫描器

在MyBatis内部是如何自定义扫描器的呢？而且还能打破Spring原有的扫描流程，将接口扫描进项目！

![image-20200915215932029](http://images.huangfusuper.cn/typora/image-20200915215932029.png)

整段代码大致分为两部分：

1. 毋庸置疑，他是创建了一个Mybatis自己的扫描器，这个扫描器是`ClassPathBeanDefinitionScanner`子类，这也是Spring为我们提供的扩展点之一，我们可以基于该扫描器，扩展任意的类变成bd，当然，他需要符合我们的预设规则！什么是预设规则呢？我们可以看到在我圈的第一个红框里面似乎做了一个注册的操作，注册的什么呢？

   ![image-20200915220235102](http://images.huangfusuper.cn/typora/image-20200915220235102.png)



​				通常情况下该判断就都是为true的，所以这里会执行一个添加的逻辑，添加到哪里了呢？

![image-20200915220432302](http://images.huangfusuper.cn/typora/image-20200915220432302.png)

​				它添加到了一个集合里面！至此，我们至少知道了，这里会向集合里面添加一个过滤器，至于有什么用，我们后面会说到，你这里先记住！

2. 我们再看第二个红框，开始执行扫描操作了！具体里面的代码我就不粘贴了，他会调用父类的扫描逻辑，我们直接看父类是如何做的！

   ![image-20200915220818278](http://images.huangfusuper.cn/typora/image-20200915220818278.png)

   

   ​		

   **这里将包路径转换为对应的bd，如何做的呢？**

   

![image-20200915221123343](http://images.huangfusuper.cn/typora/image-20200915221123343.png)

这么长的逻辑，我们重点关注两个判断：

- 第一个判断，会判断该类是否被过滤，到底该不该转换为`BeanDefinition`,还记得我们刚刚注册的那个过滤器吗？ 一个过滤器被添加进集合里面了，他就是在这里被使用的！

![image-20200915221801594](http://images.huangfusuper.cn/typora/image-20200915221801594.png)

因为那个过滤器的定义所以这里一定会返回为true!m所以我们第一个判断过了！一个类别转换成了`BeanDefinition`

- 第二个判断，会调用子类的`isCandidateComponent`方法，这里是判断一个类到底需不需要被添加进集合里面返回，我们常识得知，Spring是不会替我们管理一个接口类的，但是Mapper类又偏偏是一个接口，所以这时MyBatis不得不改写原有的逻辑使得它支持扫描接口并转换为bd,我们看下里面的逻辑！

![image-20200915221458473](http://images.huangfusuper.cn/typora/image-20200915221458473.png)

因为MyBatis的Mapper类是一个接口，所以这里会返回为true!  所以我们第二个判断进去了，一个接口的`BeanDefinition`被添加进集合！并返回！

至此，我们大概知道了扫描器的工作原理！我们看一下将接口扫描到之后做了那些操作呢？



#### 2）通过BeanDefinition操作创建流程

![image-20200915222512900](http://images.huangfusuper.cn/typora/image-20200915222512900.png)



- 他会循环遍历所有扫描到的接口bd，向每一个bd的构造方法传递一个值，他是当前bd所代表的接口的全限定名！

  上面介绍MyBatis扩展FactoryBean的时候说到！它通过jdk创建动态代理，但是接口时哪里来的？就是通过

  ```java
   definition.getConstructorArgumentValues().addGenericArgumentValue(beanClassName);
  ```

  注入进去的！我们都知道Spring创建对象是基于`definition`创建的，所以，我们可以通过`definition`来注入我们想要注入的值，他常用的用法还有类似下面的：

  ![image-20200915223229818](http://images.huangfusuper.cn/typora/image-20200915223229818.png)

  MyBatis 中正是使用构造函数 的方式注入了一个接口的值！

  ![image-20200915223354790](http://images.huangfusuper.cn/typora/image-20200915223354790.png)

- 强行将接口的类型转换为FactoryBean类型的！

  至于为什么转换为FactoryBean文章开篇说的很清楚了，这里就不详细赘述了，他是为了延迟初始化，使用jdk动态代理返回一个对象！从而完成MyBatis的功能！



### 3. 总结

![MyBatis整合Spring的实例化过程](http://images.huangfusuper.cn/typora/MyBatis整合Spring的实例化过程.png)	

