# Spring中眼见为虚的 @Configuration 配置类

## 一、前言

在这里我不得不感慨Spring的代码的完善与优秀，从之前看源码迷迷糊糊到现在基本了解Spring的部分源码后，愈来愈发现Spring开发者的思虑之周全！

之前说过学习源码的目的在哪？正如我特别喜欢的一句话，`有道无术，术尚可求也！有术无道，止于术！`，对于Spring的了解仅仅局限于使用远远不够，Spring作为一个国内绝大多数java开发者使用的一个项目管理框架，他是一个生态，什么是生态？比如现在的`SpringBoot`、`SpringCloud`,他们是什么？是Spring生态中的一个组成部分！他们利用Spring生态中提供的各种扩展点，一步一步的封装，成就了现在Spring`快速启动`、`自动配置`等亮眼的功能！作为Spring的使用者，我们理应了解Spring的实现和各种扩展点，从而能够真正的深入Spring生态！深入了，再去研究生态中的组成部分如：`SpringBoot`之流的框架，也就水到渠成了！

## 二、开篇一问

相信大部分开发者对于Spring的使用都是水到渠成的！那么下面一段代码大家一定很熟悉！

```java
/**
 * 全局配置类
 *
 * @author huangfu
 */
@Configuration
public class ExpandRunConfig {
	@Bean
	public TestService testService() {
		return new TestServiceImpl();
	}

	@Bean
	public UserService userService() {
		testService();
		return new UserServiceImpl();
    }
}
```

可以很清楚的看到，这里交给Spring管理了两个类`TestService`,`UserService`,但是在`userService()`里面又引用了`testService()`! 那么问题来了，你觉得`TestService`会被实例化几次？

相信有不少同学，张口就说`一次`，对，没错，但是为什么呢？我当时对这里的问题深深的感到自我怀疑！甚至一度怀疑自己的java基础，明明这里调用了另外一个方法，但是为什么没有进行两次实例化呢？

我问了很多同事、朋友，他们只知道这样写是没有问题的！但是具体原因不知道！为什么呢？我们带着这个问题往下看！

## 三、你看到的配置类是真的配置类吗？

我们从bean容器里面把这个配置类取出来，看一下有什么不一样！

```java
public static void main(String[] args) {
    AnnotationConfigApplicationContext ac = new AnnotationConfigApplicationContext(ExpandRunConfig.class);
    ExpandRunConfig bean = ac.getBean(ExpandRunConfig.class);
    System.out.println(bean);

}
```

我们debug看一下，我们取出来了个什么玩意！

![被代理的Spring配置类](http://images.huangfusuper.cn/typora/被代理的Spring配置类20200813.png)

果然，他不是他了，他被（玷污）代理了，而且使用的代理是`cglib`，那么这里就可以猜测一个问题，在Bean方法中调用另外一个Bean方法，他一定是通过代理来做的，从而完成了多次调用只实例化一次的功能！

到这里，解决了，原来是这样！那么现在有两个疑问：

1. 什么时候给配置类加的代理？
2. 代理逻辑里面是怎么完成多次调用返回同一个实例的功能的？

下面我们就带着两个疑问，去追一下Spring源码，看看到底是如何进行的！

## 四、代理图示

![cglib代理配置类的流程图](http://images.huangfusuper.cn/typora/cglib代理配置类的流程图20200813.png)

这张图我放出来，如果你没有了解过的话，一定是很迷惑，没关系，后面会用源码解释，而且源码看完之后，我们会大概手写一个，帮助你理解！

## 五、源码详解

不妨猜一下，看过我以前的文章的读者都应该了解！Spring创建bean实例的时候，所需要的信息是在` beanDefinitionMap`里面存放的，那么在初始化的时候解析bean的bd的时候，一定是替换了配置类bd里面的类对象，才会使后面实例化config的时候变成了一个代理对象，所以我们的入口应该在这里：

![invokerBeanFactory入口方法](http://images.huangfusuper.cn/typora/invokerBeanFactory入口方法完全体.png)

那么这里面的代码是在哪增强的呢？

```java
/**
	 * 准备配置类以在运行时为Bean请求提供服务
	 * 通过用CGLIB增强的子类替换它们。
	 */
@Override
public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) {
    ..................忽略对应的逻辑................
    //字节码增强配置类  貌似用的cglib
    enhanceConfigurationClasses(beanFactory);
    ..................忽略对应的逻辑................
}
```

调用配置类的增强逻辑  `enhanceConfigurationClasses`

```java
/**
 * 对BeanFactory进行后处理以搜索配置类BeanDefinitions； 然后，任何候选人都将通过{@link ConfigurationClassEnhancer}.
 * 候选状态由BeanDefinition属性元数据确定。
 * @see ConfigurationClassEnhancer
 */
public void enhanceConfigurationClasses(ConfigurableListableBeanFactory beanFactory) {
    // 最终需要做增强的Bean定义们
    Map<String, AbstractBeanDefinition> configBeanDefs = new LinkedHashMap<>();
    for (String beanName : beanFactory.getBeanDefinitionNames()) {
        BeanDefinition beanDef = beanFactory.getBeanDefinition(beanName);
        //什么是Full类，简单来说就是加了 @Configuration 的配置类
        if (ConfigurationClassUtils.isFullConfigurationClass(beanDef)) {
           .....忽略日志打印......
            //// 如果是Full模式，才会放进来
            configBeanDefs.put(beanName, (AbstractBeanDefinition) beanDef);
        }
    }
    if (configBeanDefs.isEmpty()) {
        // 没有什么可增强的->立即返回
        return;
    }
    //配置类增强器
    // ConfigurationClassEnhancer就是对配置类做增强操作的核心类
    //初始化会初始化两个chlib拦截类  BeanFactoryAwareMethodInterceptor 和  BeanMethodInterceptor
    //这个是重点  这个类里面的方法会产生最终的代理类
    //这个方法里面有个
    ConfigurationClassEnhancer enhancer = new ConfigurationClassEnhancer();
    //对每个Full模式的配置类，一个个做enhance()增强处理
    for (Map.Entry<String, AbstractBeanDefinition> entry : configBeanDefs.entrySet()) {
        AbstractBeanDefinition beanDef = entry.getValue();
        // 如果@Configuration类被代理，请始终代理目标类
        beanDef.setAttribute(AutoProxyUtils.PRESERVE_TARGET_CLASS_ATTRIBUTE, Boolean.TRUE);
        try {
            // 设置用户指定的bean类的增强子类
            //CGLIB是给父类生成子类对象的方式实现代理，所以这里指定“父类”类型
            Class<?> configClass = beanDef.resolveBeanClass(this.beanClassLoader);
            if (configClass != null) {
                //做增强处理，返回enhancedClass就是一个增强过的子类
                //这个是重点，这个会构建一个cglib的增强器，最终返回被代理完成的类对象！
                Class<?> enhancedClass = enhancer.enhance(configClass, this.beanClassLoader);
                //不相等，证明代理成功，那就把实际类型设置进去
                if (configClass != enhancedClass) {
                    ..... 忽略日志打印 ....
                    //这样后面实例化配置类的实例时，实际实例化的就是增强子类喽
                    //这里就是替换 config类的beanClass对象的！
                    beanDef.setBeanClass(enhancedClass);
                }
            }
        }
        catch (Throwable ex) {
            。。。。。忽略异常处理。。。。。。。
        }
    }
}
```

这个类至关重要，总共做了这样几件事：

1. 筛选配置类，只有加了 `@Configuration`的配置类才会被增强！
2. 使用`enhancer.enhance`构建一个增强器，返回增强后的代理类对象！
3. 替换配置类原始的beanClass，为代理后的class!

那么，我们最关心的是如何实现的，肯定要看`enhancer.enhance`里面的逻辑~

```java
public Class<?> enhance(Class<?> configClass, @Nullable ClassLoader classLoader) {
		// 如果已经实现了该接口，证明已经被代理过了，直接返回
		if (EnhancedConfiguration.class.isAssignableFrom(configClass)) {
			。。。。忽略日志打印。。。。
			return configClass;
		}
		//没被代理过。就先调用newEnhancer()方法创建一个增强器Enhancer
		//然后在使用这个增强器，生成代理类字节码Class对象
		//创建一个新的CGLIB Enhancer实例，并且做好相应配置
        //createClass是设置一组回调（也就是cglib的方法拦截器）
		Class<?> enhancedClass = createClass(newEnhancer(configClass, classLoader));
		if (logger.isTraceEnabled()) {
			。。。。忽略日志打印。。。。
		}
		return enhancedClass;
	}
```

这是一个过度方法，真正去构建一个代理增强器的是`newEnhancer`方法，我们似乎接近了我们要的答案！

```java
/**
	 * 创建一个新的CGLIB {@link Enhancer}实例。
	 */
private Enhancer newEnhancer(Class<?> configSuperClass, @Nullable ClassLoader classLoader) {
    Enhancer enhancer = new Enhancer();
    // 目标类型：会以这个作为父类型来生成字节码子类
    enhancer.setSuperclass(configSuperClass);
    //代理类实现EnhancedConfiguration接口，这个接口继承了BeanFactoryAware接口
    //这一步很有必要，使得配置类强制实现 EnhancedConfiguration即BeanFactoryAware 这样就可以轻松的获取到beanFactory
    enhancer.setInterfaces(new Class<?>[] {EnhancedConfiguration.class});
    // 设置生成的代理类不实现org.springframework.cglib.proxy.Factory接口
    enhancer.setUseFactory(false);
    //设置代理类名称的生成策略：Spring定义的一个生成策略 你名称中会有“BySpringCGLIB”字样
    enhancer.setNamingPolicy(SpringNamingPolicy.INSTANCE);
    enhancer.setStrategy(new BeanFactoryAwareGeneratorStrategy(classLoader));
    //设置拦截器/过滤器  过滤器里面有一组回调类，也就是真正的方法拦截实例
    enhancer.setCallbackFilter(CALLBACK_FILTER);
    enhancer.setCallbackTypes(CALLBACK_FILTER.getCallbackTypes());
    return enhancer;
}
```

如果你熟悉cglib的话，肯定对这几行代码熟悉无比，主要做了这样几件事！

1. 设置需要代理的类
2. 设置生成的代理类需要实现的接口，这里设置实现了`EnhancedConfiguration`,注意这个是一个很骚的操作，他是能够保证最终类能够从beanFactory返回的一个重要逻辑，为什么？因为`EnhancedConfiguration`是`BeanFactoryAware`的子类，Spring会回调他，给他设置一个 beanFactory ，如果你看不懂不妨先把和这个记下来，等看完在回来仔细品味一下！
3. 设置过滤器，过滤器里面其实是一组回调方法，这个回调方法是最终方法被拦截后执行的真正逻辑，我们一会要分析的也是过滤器里面这一组回调实例！
4. 返回最终的增强器！

刚刚也说了，我们需要重点关注的是这一组拦截方法，我们进入到拦截器里面，找到对应的回调实例！

`CALLBACK_FILTER`:常量对应的是一个过滤器，我们看它如何实现的：

```java
private static final ConditionalCallbackFilter CALLBACK_FILTER = new ConditionalCallbackFilter(CALLBACKS);
```

那么此时 `CALLBACKS` 就是我么要找的回调方法，点进去可以看到：

```java
// 要使用的回调。请注意，这些回调必须是无状态的。
private static final Callback[] CALLBACKS = new Callback[] {
    //这个是真正能够Bean方法多次调用返回的是一个bean实例的实际拦截方法，这个拦截器就是完全能够说明，为什么多次调用只返回
    //一个实例的问题
    new BeanMethodInterceptor(),
    //拦截 BeanFactoryAware 为里面的 setBeanFactory 赋值
    //刚刚也说了，增强类会最终实现 BeanFactoryAware 接口，这里就是拦截他的回调方法 setBeanFactory方法，获取bean工厂！
    new BeanFactoryAwareMethodInterceptor(),
    //这个说实话  真魔幻  我自己实现cglib的时候一直在报错  报一个自己抛出的异常，异常原因是没有处理object里面的eques等
    //方法，这个就是为了处理那些没有被拦截的方法的实例  这个些方法直接放行
    //这个实例里面没有实现任何的东西，空的，代表着不处理！
    NoOp.INSTANCE
};
```

具体里面每一个拦截器究竟是干嘛的，注释说的很明白，我们从第二个说起！为什么不从第一个呢？第一个比较麻烦，我们由浅入深，逐步的说！

>BeanFactoryAwareMethodInterceptor

```java
/**
	 * 拦截对任何{@link BeanFactoryAware＃setBeanFactory（BeanFactory）}的调用 {@code @Configuration}类实例，用于记录{@link BeanFactory}。
	 * @see EnhancedConfiguration
	 */
private static class BeanFactoryAwareMethodInterceptor implements MethodInterceptor, ConditionalCallback {

    @Override
    @Nullable
    public Object intercept(Object obj, Method method, Object[] args, MethodProxy proxy) throws Throwable {
        //找到本类（代理类）里名为`$$beanFactory`的字段
        Field field = ReflectionUtils.findField(obj.getClass(), BEAN_FACTORY_FIELD);
        //若没找到直接报错。若找到了此字段，就给此字段赋值
        Assert.state(field != null, "Unable to find generated BeanFactory field");
        field.set(obj, args[0]);

        // 实际的（非CGLIB）超类是否实现BeanFactoryAware？
        // 如果是这样，请调用其setBeanFactory（）方法。如果没有，请退出。
        //如果用户类（也就是你自己定义的类）自己实现了该接口，那么别担心，也会给你赋值上
        if (BeanFactoryAware.class.isAssignableFrom(ClassUtils.getUserClass(obj.getClass().getSuperclass()))) {
            return proxy.invokeSuper(obj, args);
        }
        return null;
    }

    /**
	 * 执行到setBeanFactory(xxx)方法时匹配成功
	 * @param candidateMethod 当前执行的方法
	 * @return
	 */
    @Override
    public boolean isMatch(Method candidateMethod) {
        //判断方法是不是 `setBeanFactory` 方法 
        return isSetBeanFactory(candidateMethod);
    }
    
    .........忽略不必要逻辑.........
}
```

不知道你注意没有，在最终生成的代理配置类里面有一个 `$$beanFactory`属性，这个属性就是在这里被赋值的！再把图片放出来，看最后一个属性！

![被代理的Spring配置类](http://images.huangfusuper.cn/typora/被代理的Spring配置类20200813.png)

这个拦截器的主要作用：

1. 拦截 `setBeanFactory`方法，为 `$$beanFactory`赋值！

好了，这个拦截器介绍完了，功能大家也记住了，那么，我们分析下一个拦截器，这个是重点！

>BeanMethodInterceptor

```java
/**
 * 增强{@link Bean @Bean}方法以检查提供的BeanFactory中的 这个bean对象的存在。
 * @throws Throwable 作为所有在调用时可能引发的异常的统筹 代理方法的超级实现，即实际的{@code @Bean}方法
 * 当该方法经过匹配成功后 会进入到这个拦截方法  这个是解决bean方法只被创建一次的重要逻辑
 */
@Override
@Nullable
public Object intercept(Object enhancedConfigInstance, Method beanMethod, Object[] beanMethodArgs,
                        MethodProxy cglibMethodProxy) throws Throwable {
    //通过反射，获取到Bean工厂。也就是 $$beanFactory 这个属性的值
    //也就是上一个拦截器被注入的值
    ConfigurableBeanFactory beanFactory = getBeanFactory(enhancedConfigInstance);
    //拿到Bean的名称
    String beanName = BeanAnnotationHelper.determineBeanNameFor(beanMethod);

    // 确定此bean是否为作用域代理
    //方法头上是否标注有@Scoped注解
    if (BeanAnnotationHelper.isScopedProxy(beanMethod)) {
        String scopedBeanName = ScopedProxyCreator.getTargetBeanName(beanName);
        if (beanFactory.isCurrentlyInCreation(scopedBeanName)) {
            beanName = scopedBeanName;
        }
    }
    。。。。。。忽略与本题无关的代码。。。。。。。。。。
        
    // 检查给定的方法是否与当前调用的容器相对应工厂方法。
    // 比较方法名称和参数列表来确定是否是同一个方法
    // 怎么理解这句话，参照下面详解吧
    //在整个方法里面，我认为这个判断是核心，为什么说他是核心，因为只有这个判断返回的是false的时候他才会真正的走增强的逻辑
    //什么时候会是false呢？
    //首先  spring会获取到当前使用的方法   其次会获取当前调用的方法，当两个方法不一致的时候会返回false
    //什么情况下胡不一致呢？
    //当在bean方法里面调用了另一个方法，此时当前方法和调用方法不一致，导致返回课false然后去执行的增强逻辑
    if (isCurrentlyInvokedFactoryMethod(beanMethod)) {
        // 这是个小细节：若你@Bean返回的是BeanFactoryPostProcessor类型
        // 请你使用static静态方法，否则会打印这句日志的~~~~
        // 因为如果是非静态方法，部分后置处理失效处理不到你，可能对你程序有影像
        // 当然也可能没影响，所以官方也只是建议而已~~~
        if (logger.isInfoEnabled() &&
            BeanFactoryPostProcessor.class.isAssignableFrom(beanMethod.getReturnType())) {
            ...... 忽略日志打印......
        }
        // 这表示：当前方法，就是这个被拦截的方法，那就没啥好说的
        // 相当于在代理代理类里执行了super(xxx);
        // 但是，但是，但是，此时的this依旧是代理类
        //这个事实上上调用的是本身的方法  最终会再次被调用到下面的 resolveBeanReference 方法
        //这里的设计很奇妙  为什么这么说呢？
        //了解这个方法首先要对cglib有一个基础的认识 为什么这么说呗？
        //首先要明白 cglib是基于子类集成的方式去增强的目标方法的
        //所以在不进行增强的时候就可以以很轻松的调用父类的原始方法去执行实现
        //当前调用的方法和调用的方法是一个方法的时候  就直接调用cglib父类  也就是原始类的创建方法直接创建
        //当不一样的时候  会进入到下面的方法  直接由beanFactory返回  精妙！！
        return cglibMethodProxy.invokeSuper(enhancedConfigInstance, beanMethodArgs);
    }
    //方法里调用的实例化方法会交给这里来执行
    //这一步的执行是真正的执行方式，当发现该方法需要代理的时候不调用父类的原始方法
    //而是调用我需要代理的逻辑去返回一个对象，从而完成对对象的代理
    return resolveBeanReference(beanMethod, beanMethodArgs, beanFactory, beanName);
}
```

乍一看，是不是好多，没事我们一点一点分析：

1. 首先我么看那个判断`if (isCurrentlyInvokedFactoryMethod(beanMethod))`这个判断是很重要的！他就是从`ThreadLocal`里面取出本次调用的工厂方法，前面提到过很多次工厂方法，什么是工厂方法？就是你写的那个@Bean对应的方法，我们就叫做工厂方法，我们以上面`开篇一问`里的那个代码为例!
   - 当创建 `UserServiceImpl`的时候，会先存储当前的方法对象也就是 `UserServiceImpl`的方法对象，也就是放置到`ThreadLocal`里面去！
   - 然后发现是一个代理对象，进入到代理逻辑，在代理逻辑里面，走到这个判断逻辑，发现本次拦截的方法和`ThreadLocal`里面的方法是一致的，然后就放行，开始调用真正的 `userService()`方法，执行这个方法的时候，方法内部调用了`testService();`方法！
   - 发现`testService()`又是一个代理对象，于是又走代理逻辑，然后走到这个判断，判断发现当前拦截的方法是`testService`而ThreadLocal里面的方法却是`userService`,此时判断就失败了，于是就走到另外一个分支！
   - 另外一个分支就不再执行这个方法了，而是直接去beanFactory去取这个bean，直接返回！
2. ` return cglibMethodProxy.invokeSuper(enhancedConfigInstance, beanMethodArgs);`这个是当拦截的方法是工厂方法的时候直接放行，执行父类的逻辑，为什么是父类！Cglib是基于继承来实现的，他的父类就是原始的那个没有经过代理的方法，相当于调用`super.userService()`去调用原始逻辑！
3. `resolveBeanReference(beanMethod, beanMethodArgs, beanFactory, beanName);`这个也是一会我们要看的代码逻辑，这个就是当判断不成立，也就是发现工厂方法里面还调用了另外一个工厂方法的时候，会进入到这里面！那我们看一下这里面的逻辑吧！

>resolveBeanReference方法逻辑

```java
private Object resolveBeanReference(Method beanMethod, Object[] beanMethodArgs,
                                    ConfigurableBeanFactory beanFactory, String beanName) {
		。。。。。。。。。忽略不必要代码。。。。。。。。。
        //通过getBean从容器中拿到这个实例
        //这个beanFactory是哪里来的，就是第一个拦截器里面注入的`$$beanFactory`
        Object beanInstance = (useArgs ? beanFactory.getBean(beanName, beanMethodArgs) :
                               beanFactory.getBean(beanName));

        。。。。。。。。。忽略不必要代码。。。。。。。。。
        return beanInstance;
    }
 
}
```

这里面的主要逻辑就是从beanFactory里面获取这个方法对应的bean对象，直接返回！而不是再去调用对应的方法创建！这也就是为什么多次调用，返回的实例永远只是一个的原因！

## 六、总结

整个过程比较绕，读者可以自己跟着文章调试一下源码，相信经过过深度思考，你一定有所收获！

整个过程分为两大部分：

1. 增强配置类
   - 检测加了`@Configuration`注解的配置类！
   - 创建代理对象（BeanMethodInterceptor、BeanFactoryAwareMethodInterceptor）作为增强器的回调方法！
   - 返回代理后的类对象！
   - 设置进配置类的beanClass！
2. 创建bean
   - 发现该bean创建的时候依附配置类（也就是加了@Bean的方法）！
   - 回调增强配置类的方法，并记录该方法！
   - 判断拦截的方法和记录的方法是否一致
     - 一致的话就走原始的创建逻辑！
     - 不一致，就从bean工厂获取！
   - 返回创建好的bean

收工！

-------------------------------------

才疏学浅，如果文章中理解有误，欢迎大佬们私聊指正！欢迎关注作者的公众号，一起进步，一起学习！

![](https://user-gold-cdn.xitu.io/2020/6/18/172c525fe33bb144?imageView2/0/w/1280/h/960/format/webp/ignore-error/1)