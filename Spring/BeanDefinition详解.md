## 一、BeanDefinition浅析

### 1. 基本概念了解

首先我提出一个问题：`一个java对象和一个Spring Bean有什么区别？`

这是一个经典的面试题，什么是`java Object`？万物皆对象，在Java内部所有的类，经过创建之后都可以称之为一个对象，`SpringBean也是一个java Object`， 但是Spring Bean是`脱离`于JAVA Object的，为什么这么说呢？因为一个class要想变成对象只需要`new`一下，就能够称之为一个对象，但是一个类要想变成一个Spring Bean就需要经过一系列的生命周期,什么生命周期呢？后面会说到！

至少从上面的可以知道，Spring Bean是一个特殊的Java Object, 那么他肯定有和JAVA Object有不一样的地方！

Java中 Class对象可以描述一个JAVA Object，但是因为Spring Bean是一个特殊的JAVA Object，所以Class对象不能够完整的描述一个Spring Bean,所以Spring官方单独开发了一个叫做`BeanDefinition`的类，来描述一个`SpringBean`！

### 2. 大致结构

`BeanDefinition`里面描述了很多的东西，大致如下：

![image-20200907164143213](http://images.huangfusuper.cn/typora/image-20200907164143213.png)



他里面存放了Spring创建bean的过程中所需要的一切原料！

### 3. 他是干嘛的（Spring构建它的优势）？

- **提升效率**： Spring创建一个类是通过反射创建的，创建类的时候需要一些创建信息，比如Class,比如注解信息等等，实事先将这些信息缓存起来，在创建bean的时候能够直接从缓存中获取从而达到提升创建效率的目的。
- **方便修改**：spring创建对象的时候，创建的信息全部是通过 BeanDefinition 内存储的信息来创建对象的，所以，我们可以通过修改BeanDefinition内部特定的值来改变Spring创建对象的结果！
- **方便扩展**：我们通过一些特定的接口，可以获取到一个类的所有的BeanDefinition信息，从而完成一些特定功能的实现！

## 二、Spring生命周期

> 通过上面的介绍，那么你对`BeanDefinition`有了一大概的认识，那么我们在了解整个Spring的声明周期的时候，需要了解两个概念`BeanFactoryPostProcessor`、`BeanPostProcessor`，当然这里只是普及一下概念，是为了能够让读者更加深入的去理解Spring的声明周期！

### 1. 什么是BeanFactoryPostProcessor?

我们现在通过上面的了解知道了一件事，就是Spring在创建对象之前会把class转换成一个`BeanDefinition` , 此时Spring为我们提供了一个扩展点，他可以在读取完全部的class转换为 `BeanDefinition` 之后，回调所有实现了`BeanFactoryPostProcessor` 接口的实现类，并传入工厂对象，使得使用者能够对工厂对象内部的属性进行修改，例如：对`BeanDefinition`内的信息进行修改，以达到操纵最终实例化bean的目的！

说白了，他会在扫描完项目将Class转换为`BeanDefinition` 之后在进行实例化之前进行接口的回调！ 

### 2. 什么是BeanPostProcessor?

这个类和上面那个类十分的相似，他有两个方法，两个方法的调用时机也不相同，他会在实例化之后，调用初始化方法之前进行第一次方法回调（postProcessBeforeInitialization），在执行完初始化方法之后又会进行一次回调（postProcessAfterInitialization），每次回调该类都会将当前创建好的bean传递到方法内部，从而让开发者能够自定义的修改当前bean的一些定义！

### 3. Spring生命周期浅析

那么此时，我们了解了`BeanDefinition`、`BeanPostProcessor`、`BeanFactoryPostProcessor`这三个概念之后，我们可以尝试着学习一下Spring的生命周期，学习Spring声明周期对掌握Spring源码具有举足轻重的地位！只有了解Spring的声明周期，才能够对后续Spring系列的技术进行一个详尽的源码掌握！

整个Spring的生命周期，以文字描述大概分为以下几个阶段：

1. 初始化bean容器，以方便后续的所有的读取的信息的存储！
2. 初始化内置的class文件转换为bd
3. 初始化bean工厂，设置一些默认值！
4. 向BeanFactory内部注册一些自己本身内置的Bean后置处理器
5. 执行项目内置的`BeanFactoryPostProcessor`扫描项目将所有的`@Bean、@Component....`或者`xml配置`等符合Spring读取对着的类解析成 `BeanDefinition`，存储在容器里面！
6. 执行我们自定义的 `BeanFactoryPostProcessor`
7.  注册所有的`BeanPostProcessor`到容器内部！
8.  初始化国际化资源
9. 初始化事件资源
10. 实例化class
11. 按照规则进行属性填充（自动注入）
12. 回调`BeanPostProcessors.postProcessBeforeInitialization`方法
13. 调用bean的初始化方法
14. 回调`BeanPostProcessors.postProcessAfterInitialization`方法

## 三、BeanDefinition详解

### 1. AbstractBeanDefinition

尽管我们可以通过实现`BeanDefinition`接口创建一个`自定义的BeanDefinition`，但是你是否发现，自己实现这个接口，想要创建一个`BeanDefinition`极其复杂里面几十个属性都需要你自己去设置；

Spring官方为了简化这一步骤，提供了一个抽象`AbstractBeanDefinition`,这个抽象类内部默认实现了`BeanDefinition`的绝大部分方法，对一些属性进行了默认值的赋值，极大地简化了用户自己实现一个`BeanDefinition`的难度！

#### I.  GenericBeanDefinition

他是`AbstractBeanDefinition`的子类，我们通过注解配置的bean以及我们的配置类（除`@Bean`）外的`BeanDefiniton`类型都是`GenericBeanDefinition`类型的！

#### II.  RootBeanDefinition

Spring在启动时会实例化几个初始化的`BeanDefinition`,这几个`BeanDefinition`的类型都为`RootBeanDefinition`，这个包括后续Spring的BeanDefinition会进行一个合并（这都是后话）都是`RootBeanDefinition`类型的！

我们通过 `@Bean`创建的`BeanDefinition`也是RootBeanDefinition类型，当然是属于他的子类（后面会介绍）的！

### 2. AnnotatedBeanDefinition

这个接口直接继承了`BeanDefinition`,他在原来的基础上扩展了两个方法：

![image-20200907180423084](http://images.huangfusuper.cn/typora/image-20200907180423084.png)

这两个方法是专门对注解读取的方法！所有注解标识的bean都是这个类型的bean!

#### I.  AnnotatedGenericBeanDefinition

![image-20200907180954450](http://images.huangfusuper.cn/typora/image-20200907180954450.png)

**第一种情况是配置类也就是标注了`@Configuration`注解的类会被解析成 `AnnotatedGenericBeanDefinition`**

**第二种情况是通过`@Import`导入的类会被解析成`AnnotatedGenericBeanDefinition`**

#### II. ConfigurationClassBeanDefinition

![image-20200907182021917](http://images.huangfusuper.cn/typora/image-20200907182021917.png)

**通过`@Bean`注解导入的类会被解析为`ConfigurationClassBeanDefinition`**

#### III. ScannedGenericBeanDefinition

![image-20200907182139696](http://images.huangfusuper.cn/typora/image-20200907182139696.png)

**通过`@Service、@Compent`等方式创建的bean 会以`ScannedGenericBeanDefinition`的形式存在！**

