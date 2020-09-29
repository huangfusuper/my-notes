## 一、寻找合适的构造函数创建对象

> java创建对象是基于反射来创建的！反射创建对象也是基于构造函数来创建的！Spring也不可能脱离于java之外，所以spring在创建对象之前必须要做的就是，他要确定本次创建对象，所需要的构造函数！

为什么需要推断构造函数呢？ 因为Spring在帮我们管理bean的时候它并不知道他要使用什么样的构造方法！因为我们都知道Spring给我们提供的属性注入里面有一个【构造函数注入】！假设你有两个构造函数，此时Spring就会很混乱，他也不知道应该使用哪一种！所以Spring在创建对象之前会使用一个扩展点，去推断出符合Spring条件的构造函数，然后再下面创建对象的时候，选择一个最为合适的构造函数创建对象！

推断构造函数的回调就是通过`SmartInstantiationAwareBeanPostProcessor#determineCandidateConstructors`方法来做的！SmartInstantiationAwareBeanPostProcessor是BeanPostProcessor里面的一个子类，它对原有的接口进行增加，增加determineCandidateConstructors方法，再创建对象之前会回调这个方法，推断出未来创建对象的时候可能要需要的构造方法！

![image-20200929183514382](http://images.huangfusuper.cn/typora/image-20200929183514382.png)

Spring默认的实现是: **`AutowiredAnnotationBeanPostProcessor`**

它是默认寻找加了`@Autowired`注解的构造方法，这里就不细说了，后面会有专门的篇章来介绍Spring的构造方法推断！

我们自己也可以基于这个扩展点去扩展Spring，使得Spring再创建对象前拥有更多的可能性！

## 二、解析你的各类Spring注解

> java在创建对象完成后，理所应当就是应该去开始向对象注入属性，但是有一点，在注入属性的时候就必须要知道一件事，就是那个属性需要注入！

所以Spring为了方便起见，在注入属性之前我就把你对象里面未来要操作的属性给解析了，然后保存起来，未来进行对象属性注入或其他操作的时候就不需要在进行解析了，直接从缓存中取，也从测面体现了设计模式中职责单一的特点！

对于`@Autowired`,`@Value`的解析是由`BeanPostProcessor`的子类`MergedBeanDefinitionPostProcessor#postProcessMergedBeanDefinition`来做的! 

在创建完成对象之后，填充对象之前会 进行这一步操作，解析注解`@Value、@Autowired`等注解，将对应的属性或者方法和其对应的注解属性包装成一个对象，缓存起来，以便于在填充属性的时候，直接进行从缓存获取进行属性的填充！

