关于Spring生命周期的学习，前面已经写过很多篇文章去不断的探究Spring对一个Bean的创建、管理过程，在整个SpringBean的生命周期中，`BeanPostProcessor`是不可绕过的一环，他几乎贯穿了整个Spring Bean的生命周期！几乎我们现在所熟知Bean的生命周期的功能，大部分都是由`BeanPostProcessor`完成的！比如，依赖注入、循环依赖问题、Aop等，全部都是由`BeanPostProcessor`的扩展实现的！

`BeanPostProcessor`的学习是我们理解Spring如何插手对象实例化的一个重要的转折点！我们通过`BeanPostProcessor`的扩展，能够对Spring做一些很'骚'的操作！

以往的每一篇文章，对于SpringBean生命周期的介绍，都是从程序扫描开始的，但是事实上，既然是一个Bean的声明周期，那么对于生命周期的理解就要从对象的初始化开始！本篇文章将从头到尾解析Spring BeanPostProcessor整个回调实现！

## 一、寻找合适的构造函数创建对象

> java创建对象是基于反射来创建的！反射创建对象也是基于构造函数来创建的！Spring也不可能脱离于java之外，所以spring在创建对象之前必须要做的就是，他要确定本次创建对象，所需要的构造函数！

为什么需要推断构造函数呢？ 因为Spring在帮我们管理bean的时候它并不知道他要使用什么样的构造方法！因为我们都知道Spring给我们提供的属性注入里面有一个【构造函数注入】！假设你有两个构造函数，此时Spring就会很混乱，他也不知道应该使用哪一种！所以Spring在创建对象之前会使用一个扩展点，去推断出符合Spring条件的构造函数，然后再下面创建对象的时候，选择一个最为合适的构造函数创建对象！

![image-20200930083709224](http://images.huangfusuper.cn/typora/image-20200930083709224.png)

推断构造函数的回调就是通过`SmartInstantiationAwareBeanPostProcessor#determineCandidateConstructors`方法来做的！SmartInstantiationAwareBeanPostProcessor是BeanPostProcessor里面的一个子类，它对原有的接口进行增加，增加determineCandidateConstructors方法，再创建对象之前会回调这个方法，推断出未来创建对象的时候可能要需要的构造方法！事实上！这里也会进行注解`@Lookup`的解析，后面的学习也会说到，这里不重点说！

![image-20200929183514382](http://images.huangfusuper.cn/typora/image-20200929183514382.png)

Spring默认的实现是: **`AutowiredAnnotationBeanPostProcessor`**

它是默认寻找加了`@Autowired`注解的构造方法，这里就不细说了，后面会有专门的篇章来介绍Spring的构造方法推断！

我们自己也可以基于这个扩展点去扩展Spring，使得Spring再创建对象前拥有更多的可能性！

**扩展点**：实现`AutowiredAnnotationBeanPostProcessor`接口复写`determineCandidateConstructors`方法来控制准备使用的构造函数！

## 二、解析你的各类Spring注解

> java在创建对象完成后，理所应当就是应该去开始向对象注入属性，但是有一点，在注入属性的时候就必须要知道一件事，就是那个属性需要注入！

所以Spring为了方便起见，在注入属性之前我就把你对象里面未来要操作的属性给解析了，然后保存起来，未来进行对象属性注入或其他操作的时候就不需要在进行解析了，直接从缓存中取，也从测面体现了设计模式中职责单一的特点！

![image-20200930085029741](http://images.huangfusuper.cn/typora/image-20200930085029741.png)

对于`@Autowired`,`@Value`的解析是由`BeanPostProcessor`的子类`MergedBeanDefinitionPostProcessor#postProcessMergedBeanDefinition`来做的! 

在创建完成对象之后，填充对象之前会 进行这一步操作，Spring内置了一个`AutowiredAnnotationBeanPostProcessor`的实现，他的主要作用是用于解析注解`@Value、@Autowired`等注解，将对应的属性或者方法和其对应的注解属性包装成一个对象，缓存起来，以便于在填充属性的时候，直接进行从缓存获取进行属性的填充！

**扩展点**：实现`MergedBeanDefinitionPostProcessor`接口复写`postProcessMergedBeanDefinition`方法来控制一些特殊注解的解析！

## 三、循环依赖中三级缓存的精髓

> 属性和方法解析完成之后，此时就应该开始注入属性了，在注入属性之前需要保存一个工厂对象，基于这个工厂对象能够返回一个bean对象！为什么要保存工厂对象呢？还记得Spring为了解决循环依赖中的代理问题，就创建了一个三级缓存，里面主要存放为了生成代理对象的工厂对象，这第三次回调就是这个代理对象生成器！

上期Spring三级缓存的问题说的很明白，这里为什么会放一个工厂，这里不做太多的赘述！但是，工厂对象里面是如何生成一个代理对象呢？

他是基于`SmartInstantiationAwareBeanPostProcessor#getEarlyBeanReference`的方法来解决代理逻辑的！假设对象发生了循环依赖，就会通过工厂调用这个方法，最终完成AOP的逻辑!

![image-20200930091453985](http://images.huangfusuper.cn/typora/image-20200930091453985.png)

需要注意的是，这里仅仅是设置了一个代理逻辑，并没有真正的调用，这个在整个Spring解决循环依赖中说的很明白！他的调用时机是在被依赖的时候，这里不做赘述！

## 四、你的自动注入生不生效我说的算

> 在对象初始化之后，属性注入之前，会进行一次属性是被能够被注入的回调，该胡回调会返回一个布尔类型的返回值来验证最终属性是否生效！

该方法最终会回调`InstantiationAwareBeanPostProcessor#postProcessAfterInstantiation`方法，该方法的定义如下：

![image-20200930092524103](http://images.huangfusuper.cn/typora/image-20200930092524103.png)

**扩展点**：实现`InstantiationAwareBeanPostProcessor`接口复写`postProcessAfterInstantiation`方法来控制这个类到底需不需要自动注入！

## 五、属性填充

> 属性填充是基于后置处理器来做的，这里会会寻找（二）中寻找到的@Value或@Autowirte等属性或者方法，进行对应数据的注入！

Spring自动注入属性的时候会回调，`InstantiationAwareBeanPostProcessor#postProcessProperties`回调，完成最后的属性注入！所注入的标识就是在第二步寻找到的字段和方法，通过反射进行操作！

![image-20200930120942897](http://images.huangfusuper.cn/typora/image-20200930120942897.png)

通过实现`InstantiationAwareBeanPostProcessor`重写`postProcessProperties`方法，可以在某个对象属性注入的时候，就行值得修改操作，可以插手Spring对于值的注入的问题！

和所有的都一样，都是寻找到所有的值，进行循环调用！最后返回属性与值的对应关系以供后续使用！

![image-20200930122250525](http://images.huangfusuper.cn/typora/image-20200930122250525.png)

**扩展点**：实现`InstantiationAwareBeanPostProcessor`接口复写`postProcessProperties`方法来控制这个类即将要注入的属性或方法的值！

## 六、花式Aware接口调用

> 不知道你是否使用过Spring提供的一些Aware这些额外的扩展接口，不了解的可以去了解一下，灵活使用Aware接口，可以为Spring增加很多意想不到不到的功能，比如一些`SpringUtil`当然大部分是这样命名的，就是通过Aware接口来实现的！

![image-20200930123958962](http://images.huangfusuper.cn/typora/image-20200930123958962.png)

**扩展点**：实现`以上三个接口`复写`对应的方法`可以获取对应的属性！

## 七、Spring Bean初始化前，你想干什么？

> 你想在Spring回调你的初始化方法之前做些什么吗？ Spring当然为你提供了修改的可能性！

Spring在bean初始化前会回调【**BeanPostProcessor#postProcessBeforeInitialization**】方法！

![image-20200930130522577](http://images.huangfusuper.cn/typora/image-20200930130522577.png)

**扩展点**：实现`BeanPostProcessor`复写`postProcessBeforeInitialization`方法可以在类初始化之前进行修改bean！

## 八、你想在Bean被彻底创建完成前做些什么吗？

> Spring在这一步会回调你的初始化方法，也就是实现了`InitializingBean`接口的`afterPropertiesSet`方法

![image-20200930134022751](http://images.huangfusuper.cn/typora/image-20200930134022751.png)

**扩展点**：实现`InitializingBean`复写`afterPropertiesSet（）方法`可以让bean在初始化的时候做些什么！

## 九、Spring Bean完成初始化后，你想做些什么？

> Spring完成了整个Bean的生命周期了，你想在这个时候做些什么吗？还记得Spring Aop吗？他就是在这一步进行完成的！

![image-20200930141228497](http://images.huangfusuper.cn/typora/image-20200930141228497.png)

这一步的调用是Spring生命周期的最后一步，我们所熟知的AOP 也是在这里进行装载完成的！

**扩展点**：实现`BeanPostProcessor`复写`postProcessAfterInitialization（）方法`可以修改bean的最终返回实例！

## 十、总结

![BeanPostProcessor](http://images.huangfusuper.cn/typora/BeanPostProcessor.png)

最后，祝大家双节快乐！另外，国庆期间作者就不更新了！我要出去浪一段时间，哈哈！然后作者是个穷屌丝，没钱发红包！告辞！