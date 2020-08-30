## 一、随便聊聊

又是一周过去了，对于这周的收获你还满意吗？相信一直看我文章的小伙伴都知道，Spring源码精读系列的文章已经写了好多篇了，今天依旧是和以前一样，我们来分析Spring对于事务的管理！

使用过Spring的小伙伴都应该知道，Spring可以通过配置或者再方法上加一个`@Transactional`注解，然后Spring就能够自动的对里面的JDBC操作进行管理，或提交或回滚！可能有些阅读过部分源码或者看过一切类似的文章的额同学应该知道他是基于AOP完成的对事务的管理，但是对于其实现的细节却不是很明白，今天这篇文章的目的就是给各位彻底的讲清楚Spring对于事务的封装！

## 二、原理简述

整个流畅简单来说很简单！

1. 通过注解`@EnableTransactionManagement` 导入一个`TransactionManagementConfigurationSelector`的注册器！
2. `TransactionManagementConfigurationSelector`向Spring容器里面注入两个东西，一个是AOP的处理器，一个是AOP用到的事务的拦截器！
3. 注入的AOP处理器对类进行JDK或者CGLIB动态代理，使用 事务方法拦截器完成对于Spring事务的管理！

总共也就三部分，下面我们看一下具体的细节吧！

## 三、源码领读

众所周知（哈哈，文章中经常说的一句话，老实说有些东西不是不说，而是他台基础了，都是Spring的一些用法，如果不熟悉的，后面也就不用看了，想要对源码有一定了解，肯定要会使用Spring的），众所周知，我们再需要使用到Spring的事务的时候，需要在对应的配置类或者启动类上增加一个注解 叫做`@EnableTransactionManagement`类似于下图这样：

![开启事务代码](http://images.huangfusuper.cn/typora/Spring开启事务的注解20200830.png)

整个Spring的事务问题其实就是围绕着这个 注解来做的，按照之前的套路，凡是Spring的注解上叫做`Enablexxxxxx`的注解，里面毕竟使用`@Import`导入什么见不得人的东西，当然这个对于事务的注解也不例外，我们进入到里面看一下，当然涉及到里面的代码不是我使用图片代替了！我们进入到这个注解里面看看！

![@EnableTransactionManagement源码](http://images.huangfusuper.cn/typora/EnableTransactionManagement源码注释20200830.png)

果不其然，果然使用`@Import`导入了一个叫做 `TransactionManagementConfigurationSelector` 的玩意，有关`@Import`的作用，有兴趣的读者可以翻往期文章，这里不做太多赘述，你就记得它能够向Spring注入一个类！那么不言而喻，重点也在这里面！我们进入到`TransactionManagementConfigurationSelector`的源码里面看一下具体的逻辑！

![源码逻辑事务注解](http://images.huangfusuper.cn/typora/源码逻辑事务注解selector2020208302.png)

需要注意的是`AdviceModeImportSelector` 是属于`ImportSelector`的子类，也属于Spring的内置接口之一，他的作用是通过`selectImports()`方法返回的 类全限定名数组，来创建bean!

我们需要关注的是父类的 `selectImports()`调用了上图的`selectImports(AdviceMode adviceMode)`方法，通过该方法返回的类全限定名称数组来创建bean,注解`@EnableTransactionManagement`默认的是使用 `PROXY`作为默认的代理模式，我们本章也就PROXY的模式作为讲解！上图所示，当类型为PROXY的时候，返回了两个类的全限定名称:`AutoProxyRegistrar`,`ProxyTransactionManagementConfiguration`, 我们先说`AutoProxyRegistrar`！我们进入到`AutoProxyRegistrar`里面看一下他的源码逻辑！

```java
public class AutoProxyRegistrar implements ImportBeanDefinitionRegistrar {....}
```

突然发现他是`ImportBeanDefinitionRegistrar`的子类，看过前几篇文章的大概都明白，这是我们的老朋友了，他能够提供一个回调，将一些原本没有在扫描逻辑额类，注册成bean到Spring容器里面去！我们看`registerBeanDefinitions()`方法：

```java
@Override
public void registerBeanDefinitions(AnnotationMetadata importingClassMetadata, BeanDefinitionRegistry registry) {
    .....忽略不必要源码.....
    for (String annType : annTypes) {
        .....忽略不必要源码.....
            if (mode == AdviceMode.PROXY) {
                //如果使用的是这个 proxy代理模式（默认）  就是用这个注册一个代理逻辑的对象
                AopConfigUtils.registerAutoProxyCreatorIfNecessary(registry);
                .....忽略不必要源码.....
            }
        }
    }
   .....忽略不必要源码..... 
}
```

我们进入到这个方法里面，看看到底注册了一个什么东西！进入到`AopConfigUtils.registerAutoProxyCreatorIfNecessary(registry);`

```java
@Nullable
public static BeanDefinition registerAutoProxyCreatorIfNecessary(BeanDefinitionRegistry registry) {
    //空壳方法  可以进去
    return registerAutoProxyCreatorIfNecessary(registry, null);
}
```

嘿嘿，没啥要说的，继续往下追！

```java
@Nullable
public static BeanDefinition registerAutoProxyCreatorIfNecessary(BeanDefinitionRegistry registry, @Nullable Object source) {
    //完整的注册逻辑  重点关注  InfrastructureAdvisorAutoProxyCreator 对象
    return registerOrEscalateApcAsRequired(InfrastructureAdvisorAutoProxyCreator.class, registry, source);
}
```

哦吼，这里似乎传了一个`InfrastructureAdvisorAutoProxyCreator`类，不知道干嘛的，我们暂且不说，你只需要记得，Spring能够插手事务，这个类是关键，我们一会在说，我们现在去看，他把这个类怎么了！我们继续进入到`registerOrEscalateApcAsRequired`:

```java
/**
 * 这一步就是在真正的注册这个 InfrastructureAdvisorAutoProxyCreator.class 对象
 * 完成代理操作  我们下一步就是要进入的 InfrastructureAdvisorAutoProxyCreator 对象里面看一下具体完成了 什么操作
 * @param cls InfrastructureAdvisorAutoProxyCreator 对象
 * @param registry 注册工具
 * @param source 类来源
 * @return 一个转换完成的BeanDefinition
 */
@Nullable
private static BeanDefinition registerOrEscalateApcAsRequired(Class<?> cls, BeanDefinitionRegistry registry, @Nullable Object source) {

    Assert.notNull(registry, "BeanDefinitionRegistry must not be null");
    //如果当前的bean工厂已经包含了该事务管理器
    if (registry.containsBeanDefinition(AUTO_PROXY_CREATOR_BEAN_NAME)) {
        //获取到这个BeanDefinition
        BeanDefinition apcDefinition = registry.getBeanDefinition(AUTO_PROXY_CREATOR_BEAN_NAME);
        //若当前的这个BeanDefinition 和已经存在在bean工厂里面的不一样就要进行替换 将原本的事务管理器替换成当前的
        if (!cls.getName().equals(apcDefinition.getBeanClassName())) {
            //获取当前这个bean的优先级
            int currentPriority = findPriorityForClass(apcDefinition.getBeanClassName());
            //获取当前的bean的优先级
            int requiredPriority = findPriorityForClass(cls);
            //如果当前的bean优先级大于已经存在的bean优先级 则进行替换
            if (currentPriority < requiredPriority) {
                apcDefinition.setBeanClassName(cls.getName());
            }
        }
        //相同就不执行注入  直接返回
        return null;
    }
    //这一步就是真正的想Spring注入了一个 InfrastructureAdvisorAutoProxyCreator.class 对象
    RootBeanDefinition beanDefinition = new RootBeanDefinition(cls);
    //设置源
    beanDefinition.setSource(source);
    //设置优先级
    beanDefinition.getPropertyValues().add("order", Ordered.HIGHEST_PRECEDENCE);
    beanDefinition.setRole(BeanDefinition.ROLE_INFRASTRUCTURE);
    //进行注册
    registry.registerBeanDefinition(AUTO_PROXY_CREATOR_BEAN_NAME, beanDefinition);
    return beanDefinition;
}
```

这一步，重点看一下注释，很显然，Spring将上一步传入的`InfrastructureAdvisorAutoProxyCreator.class`注入到了Spring容器里面，我们继续追下去也没有意义了，我们现在需要把目光回到`InfrastructureAdvisorAutoProxyCreator`这个类上，很显然Spring注入这个类，肯定是有用意的，我们进去看看！进入到上面注入的`InfrastructureAdvisorAutoProxyCreator`类中：

```java
public class InfrastructureAdvisorAutoProxyCreator extends AbstractAdvisorAutoProxyCreator {

	@Nullable
	private ConfigurableListableBeanFactory beanFactory;


	@Override
	protected void initBeanFactory(ConfigurableListableBeanFactory beanFactory) {
		super.initBeanFactory(beanFactory);
		this.beanFactory = beanFactory;
	}

	@Override
	protected boolean isEligibleAdvisorBean(String beanName) {
		return (this.beanFactory != null && this.beanFactory.containsBeanDefinition(beanName) &&
				this.beanFactory.getBeanDefinition(beanName).getRole() == BeanDefinition.ROLE_INFRASTRUCTURE);
	}

}
```

说实话，进来看的时候，我懵了，这里面啥也没有啊，根本找不到和事务有关的关键词，但是当我打开它的类的继承图的时候，我瞬间就明白了！我们看下它的类图！

![image-20200830132522525](http://images.huangfusuper.cn/typora/InfrastructureAdvisorAutoProxyCreator类继承图20200830.png)

他居然是`AbstractAutoProxyCreator`的子类，如果你不知道他是干嘛的，那么你想一下使用AOP源码讲解的时候，这个类是干嘛的？是处理代理的，如果你忘了，我帮你回以以下，打开`@EnableAspectJAutoProxy`的源码，看一下他注入了一个`AnnotationAwareAspectJAutoProxyCreator`类，我们看一下他的类图：

![image-20200830133413495](http://images.huangfusuper.cn/typora/AOP的实现源码注解罗及20200830.png)

通过之前的学习，可以知道他是`BeanPostProcessor`的子类，是属于Spring的bean的后置处理器，我们也大概明白Spring对于事务的管理是通过AOP进行的，那么此时就明了了，他一定会调用`postProcessBeforeInstantiation()`方法来包装类，加上代理逻辑！

我们进入到`AbstractAutoProxyCreator#postProcessAfterInitialization`方法看一下：

```java
/**
 * 如果bean被子类标识为要代理的bean，则使用配置的拦截器创建代理。
 * @see #getAdvicesAndAdvisorsForBean
 */
@Override
public Object postProcessAfterInitialization(@Nullable Object bean, String beanName) {
    if (bean != null) {
        //这里获取缓存的key然后从下面去取 什么时候缓存的呢？
        //还记得为了解决循环依赖而引进的三级缓存不，明明二级缓存就能够解决，但是偏偏使用了三级缓存，而且三级缓存还是使用了一个工厂
        //org.springframework.beans.factory.support.AbstractAutowireCapableBeanFactory.getEarlyBeanReference 没错这个方法再
        //使用工厂返回对应的代理对象的时候
        //会调用org.springframework.aop.framework.autoproxy.AbstractAutoProxyCreator.getEarlyBeanReference
        //缓存一份自己的对象，这里就直接获取了
        //这样再三级缓存进行返回了动态代理之后这里就不进行AOP的逻辑了 直接返回已经被三级缓存处理好额bean
        Object cacheKey = getCacheKey(bean.getClass(), beanName);
        //这里是判断之前存储的AOP代理类是不是和创建好的bean不一致，如果一致就证明这个bean就已经是代理类了不需要走后续的AOP逻辑了
        if (this.earlyProxyReferences.remove(cacheKey) != bean) {
            //如果判断需要代理则执行AOP代理的包装逻辑
            return wrapIfNecessary(bean, beanName, cacheKey);
        }
    }
    return bean;
}
```

熟悉不，这正是之前对于SpringAOP源码分析时的第一个方法调用，后续的调用逻辑是一致的，这里不做太多的赘述，有关详情进入到【[生气！面试官你过来，我给你手写一个Spring Aop实现！](https://mp.weixin.qq.com/s/l0FvijCTxbOBeC7DKKrxlA)】观看！

其实，至此，我们至少知道了一个问题，Spring通过`@Import`注入了一个`InfrastructureAdvisorAutoProxyCreator`，这个类时一个后置处理器，能够处理SpringAOP相关的逻辑，至少我们知道了，我们对应的类能够被AOP管理， 但是具体的事务是在那里做的呢？

此时，我们就需要看`@Import`注入的另外一个类`ProxyTransactionManagementConfiguration`了！

```java
@Configuration
public class ProxyTransactionManagementConfiguration extends AbstractTransactionManagementConfiguration {

	/**
	 * 事务注册解析器
	 * @return 返回书屋注册解析器
	 */
	@Bean(name = TransactionManagementConfigUtils.TRANSACTION_ADVISOR_BEAN_NAME)
	@Role(BeanDefinition.ROLE_INFRASTRUCTURE)
	public BeanFactoryTransactionAttributeSourceAdvisor transactionAdvisor() {
		//构建一个通知类
		BeanFactoryTransactionAttributeSourceAdvisor advisor = new BeanFactoryTransactionAttributeSourceAdvisor();
		//事务相关注解的属性
		advisor.setTransactionAttributeSource(transactionAttributeSource());
		//设置事务拦截器
		advisor.setAdvice(transactionInterceptor());
		if (this.enableTx != null) {
			advisor.setOrder(this.enableTx.<Integer>getNumber("order"));
		}
		return advisor;
	}

	@Bean
	@Role(BeanDefinition.ROLE_INFRASTRUCTURE)
	public TransactionAttributeSource transactionAttributeSource() {
		return new AnnotationTransactionAttributeSource();
	}

	/**
	 * 事务拦截器
	 * @return 返回一个事务拦截器
	 */
	@Bean
	@Role(BeanDefinition.ROLE_INFRASTRUCTURE)
	public TransactionInterceptor transactionInterceptor() {
		//这一步就是实际意义上的事务拦截器  最终会进入到这里面 执行对DB事务的管理
		//这个类被包装在 BeanFactoryTransactionAttributeSourceAdvisor 的  setAdvice 里面
		TransactionInterceptor interceptor = new TransactionInterceptor();
		interceptor.setTransactionAttributeSource(transactionAttributeSource());
		if (this.txManager != null) {
			interceptor.setTransactionManager(this.txManager);
		}
		return interceptor;
	}

}
```

好了，现在我们知道了以下几点：

1. Spring容器中有了一个特殊的后置处理器：`AbstractAutoProxyCreator`,它能够对Service进行包装，使其成为一个增强类！
2. Spring容器中有了一个特殊的方法拦截器：`TransactionInterceptor`,它能够对对应的方法进行事务的管理！

我们下面要探究的就是，AOP的处理器和方法的拦截器如何关联起来的！

有些具体的方法调用逻辑，我在【[生气！面试官你过来，我给你手写一个Spring Aop实现！](https://mp.weixin.qq.com/s/l0FvijCTxbOBeC7DKKrxlA)】写的很详细，有兴趣的小伙伴可以看看这个，本篇文章只对事务相关的逻辑进行讲解！

我们进入到AOP的处理器：`AbstractAutoProxyCreator#postProcessAfterInitialization`里面:

```java
/**
 * 如果bean被子类标识为要代理的bean，则使用配置的拦截器创建代理。
 * @see #getAdvicesAndAdvisorsForBean
 */
@Override
public Object postProcessAfterInitialization(@Nullable Object bean, String beanName) {
    if (bean != null) {
        //这里获取缓存的key然后从下面去取 什么时候缓存的呢？
        //还记得为了解决循环依赖而引进的三级缓存不，明明二级缓存就能够解决，但是偏偏使用了三级缓存，而且三级缓存还是使用了一个工厂
        //org.springframework.beans.factory.support.AbstractAutowireCapableBeanFactory.getEarlyBeanReference 没错这个方法再
        //使用工厂返回对应的代理对象的时候
        //会调用org.springframework.aop.framework.autoproxy.AbstractAutoProxyCreator.getEarlyBeanReference
        //缓存一份自己的对象，这里就直接获取了
        //这样再三级缓存进行返回了动态代理之后这里就不进行AOP的逻辑了 直接返回已经被三级缓存处理好额bean
        Object cacheKey = getCacheKey(bean.getClass(), beanName);
        //这里是判断之前存储的AOP代理类是不是和创建好的bean不一致，如果一致就证明这个bean就已经是代理类了不需要走后续的AOP逻辑了
        if (this.earlyProxyReferences.remove(cacheKey) != bean) {
            //如果判断需要代理则执行AOP代理的包装逻辑
            return wrapIfNecessary(bean, beanName, cacheKey);
        }
    }
    return bean;
}
```

进入到`wrapIfNecessary(xxxxx)`方法：

```java
protected Object wrapIfNecessary(Object bean, String beanName, Object cacheKey) {
    。。。。。。。。。忽略不需要的方法。。。。。。。。。。。
        //这里就是寻找这个bean的切点的  寻找对应的AOP代理
        //这个也是难点 他是如何寻找到该bean对应的切点的呢？
        //获取当前对象所有适用的Advisor.找到所有切点是他的对应的@Aspect注解的类
        //它主要使用的就是 第一步时获取所有的切面方法也就是  Advisor.class 类型的类
        //使用当前类一个一个的循环判断是否使用当前这个类
        //适用就添加到数组，不适应就下一个！
        Object[] specificInterceptors = getAdvicesAndAdvisorsForBean(bean.getClass(), beanName, null);
    if (specificInterceptors != DO_NOT_PROXY) {
        //如果是允许代理的话
        this.advisedBeans.put(cacheKey, Boolean.TRUE);
        //这一步是主要逻辑，创建一个代理对象  参数为：类的类对象  bean的名称  代理类的信息（位置，切点等信息）  bean对象
        Object proxy = createProxy( bean.getClass(), beanName, specificInterceptors, new SingletonTargetSource(bean));
        。。。。。。。。。忽略不需要的方法。。。。。。。。。。。
            return proxy;
    }
    。。。。。。。。。忽略不需要的方法。。。。。。。。。。。
        //返回原始的Bean对象
        return bean;
}
```

![image-20200830171859381](http://images.huangfusuper.cn/typora/事务切面debug20200830.png)

上图所示，可以看到在这里已经寻找到了这个方法拦截器！我们继续往下走，将找到的方法拦截器传入到`createProxy(xxxx)`方法，我们进去：

```java
protected Object createProxy(Class<?> beanClass, @Nullable String beanName, @Nullable Object[] specificInterceptors, TargetSource targetSource) {
    。。。。。。。。。忽略不需要的方法。。。。。。。。。。。
        //创建一个代理工厂
        ProxyFactory proxyFactory = new ProxyFactory();
    //包装代理信息 切点信息包装
    Advisor[] advisors = buildAdvisors(beanName, specificInterceptors);
    proxyFactory.setFrozen(this.freezeProxy);
    。。。。。。。。。忽略不需要的方法。。。。。。。。。。。
    //真正代理逻辑 这里主要是获取一个真正代理 参数是类加载器
    return proxyFactory.getProxy(getProxyClassLoader());
}
```

然后进入到：`getProxy(getProxyClassLoader());`方法：

```java
/**
 * 根据此工厂中的设置创建一个新的代理。
 * <p>可以反复调用。如果我们添加了效果会有所不同 或删除的接口。可以添加和删除拦截器。
 * <p>使用给定的类加载器（如果需要创建代理）。
 * @param classLoader 类加载器以创建代理 （或{@code null}为低级代理工具的默认值）
 * @return 代理对象
 */
public Object getProxy(@Nullable ClassLoader classLoader) {
    //createAopProxy返回使用的代理类型   注意在这个方法里面传入了一个this 这个有大用
    //getProxy使用返回的代理类型创建代理对象
    return createAopProxy().getProxy(classLoader);
}
```

这段逻辑就不多说了，在【[生气！面试官你过来，我给你手写一个Spring Aop实现！](https://mp.weixin.qq.com/s/l0FvijCTxbOBeC7DKKrxlA)】文章中很详细的介绍过，我们直接进入到`getProxy(classLoader);`方法，因为我们使用的时jdk动态代理，所以我们最终会进入到`JdkDynamicAopProxy#getProxy(java.lang.ClassLoader)`方法中去！

```java
@Override
public Object getProxy(@Nullable ClassLoader classLoader) {
    if (logger.isTraceEnabled()) {
        logger.trace("Creating JDK dynamic proxy: " + this.advised.getTargetSource());
    }
    Class<?>[] proxiedInterfaces = AopProxyUtils.completeProxiedInterfaces(this.advised, true);
    findDefinedEqualsAndHashCodeMethods(proxiedInterfaces);
    //调用jdk原生的代理逻辑
    return Proxy.newProxyInstance(classLoader, proxiedInterfaces, this);
}
```

> Proxy.newProxyInstance(classLoader, proxiedInterfaces, this);

上面这个方法特别重要，也是整个jdk动态代理的核心，我们可以看到最终的传入的`InvocationHandler`是`this`这代表着最终jdk动态代理所执行的回调方法`invoker`就在这个类里面，我们进入到这个类的`invoker`方法中，这里完整最终调用事务方法拦截器的最终方法！

```java
public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
    。。。。。。。。。忽略不需要的方法。。。。。。。。。。。
    // 获取此方法的拦截链。
    //这个拦截链条是对应的bean能够使用的所有的切点方法
    //这里就是上面筛选出来所有的通知类的责任链
    //org/springframework/aop/framework/autoproxy/AbstractAutoProxyCreator.java:366 注入进来的
    List<Object> chain = this.advised.getInterceptorsAndDynamicInterceptionAdvice(method, targetClass);
    if (chain.isEmpty()) {
        。。。。。。。。。忽略不需要的方法。。。。。。。。。。。
    } else {
        // 我们需要创建一个方法调用...
        MethodInvocation invocation = new ReflectiveMethodInvocation(proxy, target, method, args, targetClass, chain);
        // 通过拦截器链进入连接点。  这个是主要方法
        retVal = invocation.proceed();
    }

    。。。。。。。。。忽略不需要的方法。。。。。。。。。。。
}
```

我们看一下这个拦截链里面的元素：

![image-20200830173606951](http://images.huangfusuper.cn/typora/事务责任链元素210200830.png)

可以看到，此时的拦截器里面就一个，就是先前事务注解注入的一个方法拦截器；

我们进入到`invocation.proceed()`方法里面去：

```java
@Override
@Nullable
public Object proceed() throws Throwable {
    //	我们从索引-1开始并提前增加。
    if (this.currentInterceptorIndex == this.interceptorsAndDynamicMethodMatchers.size() - 1) {
        //当调用链全部调用完毕后  开始执行真正的目标方法
        //注意 这个是重点，为什么？
        //因为再构建的时候 会将全部的拦截器注册到调用链里面采用责任链的设计模式
        //同时会将调用链传递到每一步的方法里面，再调用链没有调用完毕之前不会调用真正的目标方法
        //而是会调用调用链里面所代表的方法执行下一个切点拦截器
        //而这一步就是真正的调用链被调用完毕之后，真正所执行的方法
        //那么这个方法就一定是调用目标方法的方法
        return invokeJoinpoint();
    }
    //interceptorsAndDynamicMethodMatchers  这里是传过来的切点方法  该bean对应几个切点  就会有几个拦截器
    Object interceptorOrInterceptionAdvice = this.interceptorsAndDynamicMethodMatchers.get(++this.currentInterceptorIndex);
    if (interceptorOrInterceptionAdvice instanceof InterceptorAndDynamicMethodMatcher) {
        。。。。。。。。。忽略不需要的方法。。。。。。。。。。。
    }
    else {
        // 它是一个拦截器，所以我们只调用它:在构造这个对象之前，切入点已经被静态地求值了。
        return ((MethodInterceptor) interceptorOrInterceptionAdvice).invoke(this);
    }
}
```

这个方法在AOP源码里面也是极其重要，但是不是本节课的重点，有兴趣的小伙伴可以参阅：【[生气！面试官你过来，我给你手写一个Spring Aop实现！](https://mp.weixin.qq.com/s/l0FvijCTxbOBeC7DKKrxlA)】

事实上上面这个代码会走到else里面，也就是会调用`(MethodInterceptor) interceptorOrInterceptionAdvice).invoke(this);`方法，我们看一下这个`interceptorOrInterceptionAdvice`的实际类型：

![image-20200830174134900](http://images.huangfusuper.cn/typora/实际类型20200830.png)

没错他最终会进入到`TransactionInterceptor#invoker`方法中去；至此为止，AOP的处理器与事务方法拦截器彻底关联上了，我们进入到这个方法里面（`注意参数里面有个this`）：

![image-20200830174428782](http://images.huangfusuper.cn/typora/事务拦截器方法内部20200830.png)

我们进入到`invokeWithinTransaction`,注意一点，他向这个方法里面传入了一个回调，不懂java8的可以看下注释，这个方法回调，是还会再回到先前的逻辑，这都是后话，我们进入到方法内部，这个你注意下，后面会说：

```java
@Nullable
protected Object invokeWithinTransaction(Method method, @Nullable Class<?> targetClass, final InvocationCallback invocation) throws Throwable {

    // 如果transaction属性为null，则该方法为非事务处理。
    TransactionAttributeSource tas = getTransactionAttributeSource();
	。。。。。。。。。忽略不需要的方法。。。。。。。。。。。
    if (txAttr == null || !(tm instanceof CallbackPreferringPlatformTransactionManager)) {
        // 使用getTransaction和commit / rollback调用进行标准事务划分。
        // 开启事务,底层会启用jdbc开启事务,
        TransactionInfo txInfo = createTransactionIfNecessary(tm, txAttr, joinpointIdentification);
        // 目标方法返回值
        Object retVal;
        try {
            // 这是一个建议：调用链中的下一个拦截器。
            // 通常，这将导致目标对象被调用。
            //这是重新回去 拿到最终的返回值 处理完成之后本代理节点完成
            retVal = invocation.proceedWithInvocation();
        }
        catch (Throwable ex) {
            // 如果目标方法抛出异常,这里会回滚事务
            completeTransactionAfterThrowing(txInfo, ex);
            throw ex;
        }
        finally {
            // 清埋事务
            cleanupTransactionInfo(txInfo);
        }
        //返回后提交事务
        commitTransactionAfterReturning(txInfo);
        return retVal;
    } else {
        。。。。。。。。。忽略不需要的方法。。。。。。。。。。。
    }
}
```

这里最终完成了方法的 提交和回滚操作，在try里面的方法调用，事实上回调用之前传入的回调函数！

![image-20200830174949184](http://images.huangfusuper.cn/typora/匿名类回调20200830.png)

会调用到，至于原因是在调用`(MethodInterceptor) interceptorOrInterceptionAdvice).invoke(this);`的时候传入了一个this!

![image-20200830175029418](http://images.huangfusuper.cn/typora/重复的回调20200830.png)

没错会重新的调用回来，最终完成对方法的一个拦截，从而完成对事务的代理！

好了本期的事务相关的源码分析就介绍完了，有什么疑惑的或者其他方面的可以私聊或留言作者哦！

## 四、徐晃一枪来波总结

哈哈，按照之前的逻辑，老皇我怎么会不画图总结一番呢！我把之前的那些源码逻辑总结为下图所示，希望对你有所帮助：

![Spring事务源码流程图](http://images.huangfusuper.cn/typora/Spring事务源码流程图.png)



【推荐阅读】



1. [牛逼哄哄的Spring是怎么被MyBatis给征服了?](https://mp.weixin.qq.com/s/5M0dL3O6y-zG3-oPRruihQ)
2. [Spring中眼见为虚的 @Configuration 配置类](https://mp.weixin.qq.com/s/slTtgTULME6uvDh6RNq33g)
3. [生气！面试官你过来，我给你手写一个Spring Aop实现](https://mp.weixin.qq.com/s/l0FvijCTxbOBeC7DKKrxlA)
4. [万字长文，助你深度遨游Spring循环依赖源码实现](https://mp.weixin.qq.com/s/2dXsYOh5a7-56qy31A0OWA)
5. [听说你一读Spring源码就懵？我帮你把架子搭好了，你填就行](https://mp.weixin.qq.com/s/mbkP8buaQCYZrLyuH-j2UA)