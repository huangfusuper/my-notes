# 一、拉拉家常

又是一周过去了，不知上周发的关于[Spring循环依赖](https://mp.weixin.qq.com/s/2dXsYOh5a7-56qy31A0OWA)使用的三级缓存你们掌握到什么样子了呢？这周又是一篇深度好文（自夸一下），作者每天下班肝了好几天赶出来的文章，有没有很感动，哈哈（疯狂暗示点个赞）！相信有读者看到了昨天我发的朋友圈，有关`Spring AOP`的源码级别的注释，那么这个也是本篇文章的主体，不用多说涉及到源码，肯定是一个长文，希望大家有所收获！

说到`Spring Aop`无论是面试还是开发都是绕不过的一个坎 ，相信不少同学工作中也是经常性的使用AOP去搞一些日志啦权限啦或者校验之类的开发，但是实际上不少同学开发过程中基本都是去网上找一篇帖子，施展CV大法，然后改改就用到生产了！对原理也是基本不了解，让我感触最深的一个事就是，面试的一个小伙子，当我问到AOP使用的是那种代理模式时，面试者给我一个很轻蔑的眼神，来了句使用的`Cglib 动态代理`，哎，也不怪我筛选掉你不是！

开篇一问：Spring Aop使用的是那种动态代理模式呢？相信你会在图中找到答案！

![image-20200808231235002](http://images.huangfusuper.cn/typora/aop202008080808.png)

没错，两种模式都会使用，当存在接口的时候是`jdk动态代理`，不存在接口的时候是`cglib`动态代理！对应的实现类是：`CglibAopProxy`和`JdkDynamicAopProxy`,后续文章会给出介绍！

本篇文章呢，还是会和上一篇文章`Spring如何解决循环依赖`一样，先自己实现一个Aop动态代理，然后看Spring是如何实现的！

# 二、自己尝试实现一下

那么，我们再实现AOP的时候，应该怎么去考虑呢？

首先我们肯定要先找到所有的切面，就是我们加了`@Aspect`注解的那个方法，找到之后，我们再创建bean的时候，先判断是否符合切面，是否需要代理，需要代理就走代理的逻辑，不需要就走自己的逻辑！

## 1.定义通知类型

首先，我们先定义一个类似于通知类型的注解（对应Spring的前置通知、后置通知等），这里以环绕通知为例，定义一个注解：

```java
/**
 * 模拟一个环绕通知
 * @author huangfu
 */
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface MyAround {
	/**
	 * 要拦截的携带什么注解的方法
	 * @return 返回这个注解的class
	 */
	Class<? extends Annotation> targetClass();
}
```

里面的属性就是切点，这里以注解为例，意思就是，只要你方法上加了 `targetClass`设置的注解，那么就会被AOP拦截！

## 2.定义一个代理链的类

`注意：想直接看源码的请跳到第三章！！自己实现的逻辑不短！！！`

`注意：想直接看源码的请跳到第三章！！自己实现的逻辑不短！！！`

`注意：想直接看源码的请跳到第三章！！自己实现的逻辑不短！！！`

这个类是干嘛的，Spring中采用责任链的设计模式，设计一个方法对应多个切点，这里我们也采用这种设计模式！

```java
package simulation.aop.system;

import lombok.Data;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

/**
 * 代理调用信息  切点代理方法
 * @author huangfu
 */
@Data
public class ProxyChain {
	/**
	 * 切点的方法
	 */
	private Method method;
	/**
	 * 切点的对象
	 */
	private Object target;
	/**
	 * 切点的参数
	 */
	private Object[] args;

	public ProxyChain(Method method, Object target, Object... args) {
		this.method = method;
		this.target = target;
		this.args = args;
	}

	public Object invoker() throws InvocationTargetException, IllegalAccessException {
		method.setAccessible(true);
		return method.invoke(target, args);
	}
}
```

## 3.定义通知里面的上下文对象参数

什么是上下文参数呢？以Spring为例，假设我们开发一个环绕通知，环绕通知里面的方法参数叫做`ProceedingJoinPoint`,那么我们也定义一个类似这样的方法，咱们叫做`MyProceedingJoinPoint`

```java
package simulation.aop.system;

import lombok.Data;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

/**
 * @author huangfu
 */
@Data
public class MyProceedingJoinPoint {
	/**
	 * 目标方法的参数
	 */
	private Object[] args;
	/**
	 * 目标对象
	 */
	private Object target;
	/**
	 * 目标方法
	 */
	private Method method;
	/**
	 * 存在的调用链
	 */
	private List<ProxyChain> proxyChains = new ArrayList<>(8);
	/**
	 * 当前调用链的指针位置
	 */
	private int chainsIndex = 0;


	public Object proceed(Object[] args) throws InvocationTargetException, IllegalAccessException {
		return method.invoke(target,args);
	}

	public Object proceed() throws InvocationTargetException, IllegalAccessException {
		return method.invoke(target);
	}
}

```

## 4.开发一个jdk动态代理所需要的回调方法（InvocationHandler）

熟悉jdk动态代理的小伙伴基本应该知道这个是干嘛的把，代理对象最终执行的逻辑是这个类里面的`invoker`方法，不熟悉的小伙伴希望去恶补一下再回来，最起码要知道它的使用方式！

```java
package simulation.aop.system;

import org.springframework.util.CollectionUtils;

import java.io.Serializable;
import java.lang.annotation.Annotation;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * 动态代理执行器
 *
 * @author huangfu
 */
public class MyJdkDynamicAopProxy implements InvocationHandler, Serializable {
	int chainsIndex = 0;
	Object target;

	private final BeanUtil beanUtil;

	public MyJdkDynamicAopProxy(BeanUtil beanUtil, Object target) {
		this.beanUtil = beanUtil;
		this.target = target;
	}

	@Override
	public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {

		Method targetMethod = target.getClass()
            			.getMethod(method.getName(), method.getParameterTypes());
		Annotation[] targetAnnotations = targetMethod.getDeclaredAnnotations();
		//没注解  不代理
		if (targetAnnotations.length <= 0) {
			return method.invoke(target, args);
		}
		List<ProxyChain> proxyChains = new ArrayList<>(8);
		//获取这个方法的所有的注解，获取所以配置注解的切面方法
		Arrays.stream(targetAnnotations).forEach(annotation -> {
			Class<? extends Annotation> annotationClass = annotation.annotationType();
			if (beanUtil.proxyRule.containsKey(annotationClass.getName())) {
				proxyChains.addAll(beanUtil.proxyRule.get(annotationClass.getName()));
			}
		});
		//若拦截规则为空就直接执行就行了
		if (CollectionUtils.isEmpty(proxyChains)) {
			return method.invoke(target, args);
		}
		//当调用链执行完了就代表拦截方法全部执行完了，此时就可以回调自己的方法了！
		if (chainsIndex == proxyChains.size()) {
			return method.invoke(target, args);
		}
		//构建参数
		MyProceedingJoinPoint myProceedingJoinPoint = new MyProceedingJoinPoint();
		myProceedingJoinPoint.setArgs(args);
		myProceedingJoinPoint.setMethod(method);
		myProceedingJoinPoint.setProxyChains(proxyChains);
		myProceedingJoinPoint.setTarget(proxy);

		ProxyChain proxyChain = proxyChains.get(chainsIndex++);
		myProceedingJoinPoint.setChainsIndex(chainsIndex);
		//设置对应执行链节点的参数
		proxyChain.setArgs(new Object[]{myProceedingJoinPoint});
		//执行该节点对应的方法
		return proxyChain.invoker();
	}
}
```

## 5.开发一个使用的工具类

对应Spring的bean工厂，当然里面大部分和本篇无关的逻辑都被我简化写死了，读者只需要关注和本篇文章有关的内容就好了！

```java
package simulation.aop.system;

import simulation.aop.my.MyAspect;
import simulation.aop.my.TestServiceImpl;

import java.lang.annotation.Annotation;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 模拟AOP实现
 *
 * @author huangfu
 */
@SuppressWarnings("all")
public class BeanUtil {
	/**
	 * 假设这是单例池   模仿Spring,存放已经弄好的对象
	 */
	public final Map<String, Object> beanCache = new ConcurrentHashMap<>(8);

	/**
	 * 假设这是bd map 存放bean的信息 这里相对Spring进行简化了，只存储类对象足够我们使用了
	 */
	public final Map<String, Class> beanClassCache = new ConcurrentHashMap<String, Class>(8);
	/**
	 * 假设这是bean容器里面存储切面的缓存  存储的是切面的缓存
	 */
	public final List<Class> aspectjClassCache = new ArrayList<>(8);

	/**
	 * 拦截规则  存储注解对应的规则链
	 */
	public final Map<String, List<ProxyChain>> proxyRule = new ConcurrentHashMap<>();

	/**
	 * 我们假设Spring完成了基础扫描步骤，已经将bd存放再了容器里面
	 * 假设假设哈
	 */
	public BeanUtil() throws InstantiationException, IllegalAccessException {
		beanClassCache.put("testService", TestServiceImpl.class);
		aspectjClassCache.add(MyAspect.class);
		//解析切面
		parseAspectjClass();
	}


	/**
	 * 初始化bean
	 */
	public void initBean() {
		beanClassCache.forEach((key, value) -> {
			//判断是否有需要代理的方法
			try {
				//创建所有的类 转换为bean
				createBean(key, value, hasProxy(value));
			} catch (IllegalAccessException e) {
				e.printStackTrace();
			} catch (InstantiationException e) {
				e.printStackTrace();
			}

		});
	}

	/**
	 * 创建bean
	 *
	 * @param beanName bean的名称
	 * @param classes  bean的类对象
	 * @param isProxy  是否需要代理
	 */
	public void createBean(String beanName, Class classes, boolean isProxy) throws IllegalAccessException, InstantiationException {
		Class<?>[] interfaces = getInterfaces(classes);
		Object target = classes.newInstance();
		//需要被代理 这里没有模仿cglib而是使用的jdk动态代理 所以必须需要接口 Spring是两种接口混合使用的
		if (isProxy && interfaces != null && interfaces.length > 0) {
			//创建jdk动态代理的对象
			MyJdkDynamicAopProxy myJdkDynamicAopProxy = new MyJdkDynamicAopProxy(this, target);
			//返回代理对象
			target = Proxy.newProxyInstance(BeanUtil.class.getClassLoader(), interfaces, myJdkDynamicAopProxy);
			//存储再缓存池
			beanCache.put(beanName, target);
		} else {
			//不需要代理也存储再缓存池
			beanCache.put(beanName, target);
		}
	}

	/**
	 * 获取bean对象
	 *
	 * @param beanName beanName
	 * @param <T>
	 * @return
	 */
	public <T> T getBean(String beanName) {
		return (T) beanCache.get(beanName);
	}


	/**
	 * 获取对应类的接口
	 *
	 * @param classes 要获取的类对象
	 * @return 该类对象的接口
	 */
	private Class<?>[] getInterfaces(Class classes) {
		return classes.getInterfaces();
	}

	/**
	 * 内部是否存在需要被拦截的方法对象
	 *
	 * @param targetClass 目标类对象
	 * @return 返回是否需要代理
	 */
	private boolean hasProxy(Class targetClass) {
		//获取所有的方法
		Method[] declaredMethods = targetClass.getDeclaredMethods();
		for (Method method : Arrays.asList(declaredMethods)) {
			//获取方法上的注解
			Annotation[] declaredAnnotations = method.getDeclaredAnnotations();
			//当方法存在注释的时候 开始判断是否方法需要被代理
			if (declaredAnnotations != null && declaredAnnotations.length > 0) {
				for (Annotation annotation : Arrays.asList(declaredAnnotations)) {
					//如果解析规则存在这个注解就返回true
					if (proxyRule.containsKey(annotation.annotationType().getName())) {
						return true;
					}
				}
			}
		}
		return false;
	}

	/**
	 * 解析切面类
	 */
	private void parseAspectjClass()  throws IllegalAccessException, InstantiationException {
		for (Class aClass : aspectjClassCache) {
			//获取切面的所有方法
			Method[] declaredMethods = aClass.getDeclaredMethods();
			for (Method method : Arrays.asList(declaredMethods)) {
				//寻找携带MyAround注解的切面方法
				MyAround myAroundAnntation = method.getAnnotation(MyAround.class);
				if (myAroundAnntation != null) {
					//拿到切点标志 也就是未来切点的方法
					Class<? extends Annotation> targetClassAnnotation 
                        						= myAroundAnntation.targetClass();
					//实例化切面
					Object proxyTarget = aClass.newInstance();
					//创建调用链实体
					ProxyChain proxyChain = new ProxyChain(method, proxyTarget);
					//构建对应规则的调用链
					String classAnnotationName = targetClassAnnotation.getName();
					if (proxyRule.containsKey(classAnnotationName)) {
						proxyRule.get(classAnnotationName).add(proxyChain);
					} else {
						List<ProxyChain> proxyChains = new ArrayList<>();
						proxyChains.add(proxyChain);
						proxyRule.put(classAnnotationName, proxyChains);
					}
				}
			}
		}
	}


}
```

具体的逻辑介绍，看文中注释，此时我们的AOP就开发完了，赶紧，去测一下！

## 6.开发一个通知注解

这个注解是为了标识那些方法需要被拦截的！

```java
package simulation.aop.system;

import java.lang.annotation.*;

/**
 * 模拟AOP通过注解方式添加拦截器
 * @author huangfu
 */
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface MyAopAnnotation {
}
```

## 7.开发一个切面

```java
package simulation.aop.my;

import simulation.aop.system.MyAopAnnotation;
import simulation.aop.system.MyAround;
import simulation.aop.system.MyProceedingJoinPoint;

import java.lang.reflect.InvocationTargetException;

/**
 * 定义一个切面
 * @author huangfu
 */
public class MyAspect {

	/**
	 * 拦截所有方法上携带  MyAopAnnotation 注解的方法
	 * @param joinPoint
	 * @return
	 * @throws InvocationTargetException
	 * @throws IllegalAccessException
	 */
	@MyAround(targetClass = MyAopAnnotation.class)
	public Object testAspect(MyProceedingJoinPoint joinPoint) throws InvocationTargetException, IllegalAccessException {
		long startTime = System.currentTimeMillis();
		//方法放行
		Object proceed = joinPoint.proceed(joinPoint.getArgs());
		long endTime = System.currentTimeMillis();
		System.out.println("总共用时："+(endTime - startTime));
		return proceed;
	}


	/**
	 * 拦截所有方法上携带  MyAopAnnotation 注解的方法
	 * @param joinPoint
	 * @return
	 * @throws InvocationTargetException
	 * @throws IllegalAccessException
	 */
	@MyAround(targetClass = MyAopAnnotation.class)
	public Object testAspect2(MyProceedingJoinPoint joinPoint) throws InvocationTargetException, IllegalAccessException {
		long startTime = System.currentTimeMillis();
		//方法放行
		Object proceed = joinPoint.proceed(joinPoint.getArgs());
		long endTime = System.currentTimeMillis();
		System.out.println("总共用时："+(endTime - startTime));
		return proceed;
	}
}
```

## 8.开发一个接口和一个实现类

```java
package simulation.aop.my;

/**
 * @author huangfu
 */
public interface TestService {
	/**
	 * 打印一句话  拦截方法
	 * @param msg 返回信息
	 */
	String print(String msg) throws InterruptedException;
	/**
	* 普通方法 不拦截
	**/
	void sendUser();
}
```

```java
package simulation.aop.my;

import simulation.aop.system.MyAopAnnotation;

/**
 * 实现类
 * @author huangfu
 */
public class TestServiceImpl implements TestService {

	@MyAopAnnotation
	@Override
	public String print(String msg) throws InterruptedException {
		System.out.println("我执行了，参数是："+msg);
		Thread.sleep(5000);
		return msg;
	}

	@Override
	public void sendUser() {
		System.out.println("----发送信息---");
	}
}
```

## 9.最终测试

```java
package simulation.aop;

import simulation.aop.my.TestService;
import simulation.aop.system.BeanUtil;

public class TestMyProxy {

	public static void main(String[] args) throws IllegalAccessException, InstantiationException, InterruptedException {
		BeanUtil beanUtil = new BeanUtil();
		beanUtil.initBean();
		TestService testService = beanUtil.getBean("testService");
		System.out.println(testService.print("wqewqeqw"));
		testService.sendUser();
	}
}

```

## 10.结果

![image-20200808234158861](http://images.huangfusuper.cn/typora/result2020080900.png)

当然，肯定是成功的，但是写到这我慌了，为什么？现在就已经超过1w字了，源码部分还一个没动，天哪，我得去前面加个：不想看自己实现部分就跳过的提示！

# 三、Spring AOP源码学习

上篇文章，对有关Spring实例化，自动注入属性做了很详细的介绍有兴趣可以到【[万字长文，助你深度遨游Spring循环依赖源码实现！](https://mp.weixin.qq.com/s/2dXsYOh5a7-56qy31A0OWA)】查看,本篇文章对它实例化等操作直接略过，先看一张图，找到入口方法，我们好继续看源码：

![image-20200808235444290](http://images.huangfusuper.cn/typora/AOP方法入口源码解析20200808.png)

第一列【[万字长文，助你深度遨游Spring循环依赖源码实现！](https://mp.weixin.qq.com/s/2dXsYOh5a7-56qy31A0OWA)】说的很详细，我么从第二列开始说起：

```java
protected Object initializeBean(final String beanName, final Object bean, @Nullable RootBeanDefinition mbd) {
		.........忽略不必要代码..........
		if (mbd == null || !mbd.isSynthetic()) {
			//调用这个bean 后置处理器的前置处理器 {@link BeanPostProcessor#postProcessBeforeInitialization()}
			wrappedBean = applyBeanPostProcessorsBeforeInitialization(wrappedBean, beanName);
		}
		try {
			//回调初始化方法
			invokeInitMethods(beanName, wrappedBean, mbd);
		} catch (Throwable ex) {
			throw new BeanCreationException( (mbd != null ? mbd.getResourceDescription() : null), beanName, "Invocation of init method failed", ex);
		}
		if (mbd == null || !mbd.isSynthetic()) {
			//回调bean后置处理器的后置方法 {@link BeanPostProcessor#postProcessAfterInitialization()}
			//这里也是AOP完成装载的地方，这一步也就到达了一个类从正常的类变成bean的最后一步
			wrappedBean = applyBeanPostProcessorsAfterInitialization(wrappedBean, beanName);
		}

		return wrappedBean;
	}
```

在调用初始化方法后，会回调`BeanPostProcessors`的`postProcessAfterInitialization`方法完成AOP的加载，我们进入到：`applyBeanPostProcessorsAfterInitialization`方法：

```java
@Override
public Object applyBeanPostProcessorsAfterInitialization(Object existingBean, String beanName)
    throws BeansException {

    Object result = existingBean;
    //AOP的后置处理器被
    //{@link org.springframework.aop.framework.autoproxy.AbstractAutoProxyCreator.postProcessAfterInitialization} 拦截
    for (BeanPostProcessor processor : getBeanPostProcessors()) {
        Object current = processor.postProcessAfterInitialization(result, beanName);
        if (current == null) {
            return result;
        }
        result = current;
    }
    return result;
}
```

在这里，Spring会扫描所有的`BeanPostProcessor`实现类，然后调用全部的`postProcessAfterInitialization`方法，而AOP就是再一个叫做`AbstractAutoProxyCreator`的类处理的，我们进入到`org.springframework.aop.framework.autoproxy.AbstractAutoProxyCreator#postProcessAfterInitialization`方法：

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
        //使用工厂返回对应的代理对象的时候，
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

当判断该类需要被代理了，就进入到`wrapIfNecessary`方法：

```java
/**
 * 必要时包装给定的bean，即是否有资格被代理。
 * @param bean 原始bean实例
 * @param beanName 豆的名字
 * @param cacheKey 用于元数据访问的缓存键
 * @return 包装Bean的代理，或按原样封装Raw Bean实例
 */
protected Object wrapIfNecessary(Object bean, String beanName, Object cacheKey) {
    //如果已经处理过（targetSourcedBeans存放已经增强过的bean）
    if (StringUtils.hasLength(beanName) && this.targetSourcedBeans.contains(beanName)) {
        return bean;
    }
    ////advisedBeans的key为cacheKey，value为boolean类型，表示是否进行过代理
    //如果设置了不允许代理，就直接返回
    if (Boolean.FALSE.equals(this.advisedBeans.get(cacheKey))) {
        return bean;
    }
    //如果是本身就是AOP类 比如加了 @Asptj的类等一些基础设置会跳过不做代理，同时会将该类标注为不允许代理
    //Advice、Pointcut、Advisor、AopInfrastructureBean
    //设置了跳过  但是这个我需要后续取看
    // TODO 不是这次看到主要代码 以后看
    if (isInfrastructureClass(bean.getClass()) || shouldSkip(bean.getClass(), beanName)) {
        this.advisedBeans.put(cacheKey, Boolean.FALSE);
        return bean;
    }

    //这里就是寻找这个bean的切点的  寻找对应的AOP代理
    //获取当前对象所有适用的Advisor.找到所有切点是他的对应的@Aspect注解的类
    //注意这里会返回该bean对应的所有的切面
    Object[] specificInterceptors = getAdvicesAndAdvisorsForBean(bean.getClass(), beanName, null);
    if (specificInterceptors != DO_NOT_PROXY) {
        //如果是允许代理的话
        this.advisedBeans.put(cacheKey, Boolean.TRUE);
        //这一步是主要逻辑，创建一个代理对象  参数为：类的类对象  bean的名称  代理类的信息（位置，切点等信息）  bean对象
        Object proxy = createProxy( bean.getClass(), beanName, specificInterceptors, new SingletonTargetSource(bean));
        this.proxyTypes.put(cacheKey, proxy.getClass());
        return proxy;
    }
    //如果查询出该类不允许被代理，将该bean 修改为不可代理！
    this.advisedBeans.put(cacheKey, Boolean.FALSE);
    //返回原始的Bean对象
    return bean;
}
```

我们寻找到这个bean对应所有的切面方法，然后进入到`createProxy`方法却具体的创建代理对象:

```java
/**
 * 为给定的bean创建一个AOP代理。
 * @param beanClass bean的类型
 * @param beanName bean的名字
 * @param specificInterceptors 一组拦截器信息
 * 特定于此bean（可以为空，但不能为null）
 * @param targetSource 代理的对象
 * 已经预先配置为访问Bean
 * @return Bean的AOP代理
 * @see #buildAdvisors
 */
protected Object createProxy(Class<?> beanClass, @Nullable String beanName,
                             @Nullable Object[] specificInterceptors, TargetSource targetSource) {
    //判断beanFactory的类型
    if (this.beanFactory instanceof ConfigurableListableBeanFactory) {
        //提前暴露这个bean是一个代理的类 如何设置呢？
        //就是再该bean的bd下面设置一个代理信息
        AutoProxyUtils.exposeTargetClass((ConfigurableListableBeanFactory) this.beanFactory, beanName, beanClass);
    }
    //创建一个代理工厂
    ProxyFactory proxyFactory = new ProxyFactory();
    //设置初始化参数
    proxyFactory.copyFrom(this);

    if (!proxyFactory.isProxyTargetClass()) {
        if (shouldProxyTargetClass(beanClass, beanName)) {
            proxyFactory.setProxyTargetClass(true);
        }
        else {
            //正常的代理逻辑 判断设置一些代理参数
            evaluateProxyInterfaces(beanClass, proxyFactory);
        }
    }
    //包装代理信息 切点信息包装
    //这里是把所有的切面信息包装成了Advisor方便设置进工厂
    Advisor[] advisors = buildAdvisors(beanName, specificInterceptors);
    //向工厂设置代理切点信息
    proxyFactory.addAdvisors(advisors);
    //设置代理的目标类的包装类  嘿嘿嘿
    proxyFactory.setTargetSource(targetSource);
    //空方法  Spring没做实现  扩展点
    customizeProxyFactory(proxyFactory);

    proxyFactory.setFrozen(this.freezeProxy);
    if (advisorsPreFiltered()) {
        proxyFactory.setPreFiltered(true);
    }
    //真正代理逻辑 这里主要是获取一个真正代理 参数是类加载器
    return proxyFactory.getProxy(getProxyClassLoader());
}
```

进入到`getProxy`方法：

```java
/**
 * 根据此工厂中的设置创建一个新的代理。
 * <p>可以反复调用。如果我们添加了效果会有所不同 或删除的接口。可以添加和删除拦截器。
 * <p>使用给定的类加载器（如果需要创建代理）。
 * @param classLoader 类加载器以创建代理 （或{@code null}为低级代理工具的默认值）
 * @return 代理对象
  */
public Object getProxy(@Nullable ClassLoader classLoader) {
    //createAopProxy返回使用的代理类型
    //getProxy使用返回的代理类型创建代理对象
    return createAopProxy().getProxy(classLoader);
}
```

这里实际上就是我们上述图示上说的判断代理类型是jdk还是cglib的地方，首先我们分成两部分看：进入到`createAopProxy()`方法：

```java
protected final synchronized AopProxy createAopProxy() {
		if (!this.active) {
			activate();
		}
		//使用之前创建的工厂选取一个代理方式  究竟是jdk还是cglib
		return getAopProxyFactory().createAopProxy(this);
	}
```

不做太多解释，直接到`createAopProxy(this)`方法：

```java
@Override
public AopProxy createAopProxy(AdvisedSupport config) throws AopConfigException {
    //三个条件
    //1.设置了优化
    //2.proxyTargetClass 前面设置的 
    //{@link org.springframework.aop.framework.ProxyProcessorSupport.evaluateProxyInterfaces} 设置的是否有接口 没有接口就为true
    //3.没接口
    if (config.isOptimize() || config.isProxyTargetClass() || hasNoUserSuppliedProxyInterfaces(config)) {
        .............老规矩忽略不必要代码.........
        if (targetClass.isInterface() || Proxy.isProxyClass(targetClass)) {
            return new JdkDynamicAopProxy(config);
        }
        //返回一个cglib代理类！
        return new ObjenesisCglibAopProxy(config);
    }
    else {
        //以上条件不成立  存在接口就返回一个jdk动态代理！
        return new JdkDynamicAopProxy(config);
    }
}
```

所以说我们上述的`createAopProxy`方法是返回的使用的那种代理类型，然后我们再看`createAopProxy(this);`这个方法有两个实现类，一个是`cglib`的一个是`jdk`的，我们本篇文章以jdk动态代理为例，cglib我不会，哈哈哈！

```java
/**
 * JDK动态代理的创建代理的逻辑
 * @param classLoader 类加载器以创建代理 （或{@code null}为低级代理工具的默认值）
 * @return 代理对象
 */
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

看到这里，泪流满面，居然看到了熟悉的代码：`Proxy.newProxyInstance`没错，这里就是最终返回的代理对象，AOP至此完成代理返回！

其实熟悉jdk动态代理的都知道，最终使用的时候，jdk动态代理会调用谁？没错`this.invoke`方法：

```java
@Override
@Nullable
public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
    ....................忽略不必要的代码...........................

        // 获取此方法的拦截链。
        //这个拦截链条是对应的bean能够使用的所有的切点方法
        //这个拦截链就是我们自己实现的时候的`ProxyChain`类，他就是为了解决多个方法被多个切点拦截的问题
        //假设我们有两个环绕通知都拦截test方法，那么这个chain就有两个元素，分别对应着两个环绕通知
        List<Object> chain = this.advised.getInterceptorsAndDynamicInterceptionAdvice(method, targetClass);

    // 检查我们是否有任何建议。如果我们不这样做，我们可以退回直接 目标的反射调用，并避免创建MethodInvocation。
    //拦截连如果没有的话会直接执行对应的方法
    if (chain.isEmpty()) {
        //跳过创建MethodInvocation的方法：直接调用目标 请注意，最终调用者必须是InvokerInterceptor
        //这里只是对目标的反射操作，没有热插拔或花哨的代理。
        Object[] argsToUse = AopProxyUtils.adaptArgumentsIfNecessary(method, args);
        retVal = AopUtils.invokeJoinpointUsingReflection(target, method, argsToUse);
    }
    else {
        // 我们需要创建一个方法调用...
        MethodInvocation invocation = new ReflectiveMethodInvocation(proxy, target, method, args, targetClass, chain);
        // 通过拦截器链进入连接点。  这个是主要方法
        retVal = invocation.proceed();
    }
    ....................忽略不必要的代码...........................
}
```

我们进入到`invocation.proceed();`方法：

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
    Object interceptorOrInterceptionAdvice =
        this.interceptorsAndDynamicMethodMatchers.get(++this.currentInterceptorIndex);
    if (interceptorOrInterceptionAdvice instanceof InterceptorAndDynamicMethodMatcher) {
        // 这里评估动态方法匹配器:静态部分已经有了
        // 被评估和发现匹配。
        InterceptorAndDynamicMethodMatcher dm = (InterceptorAndDynamicMethodMatcher) interceptorOrInterceptionAdvice;
        Class<?> targetClass = (this.targetClass != null ? this.targetClass : this.method.getDeclaringClass());
        if (dm.methodMatcher.matches(this.method, targetClass, this.arguments)) {
            //方法的调用逻辑  注意：这里执行的并不是目标方法的逻辑，而是AOP切面方法的逻辑
            return dm.interceptor.invoke(this);
        }
        else {
            // 动态匹配失败。  不是InterceptorAndDynamicMethodMatcher类型的
            // 跳过此拦截器并调用链中的下一个拦截器。  递归
            return proceed();
        }
    }
    else {
        // 它是一个拦截器，所以我们只调用它:在构造这个对象之前，切入点已经被静态地求值了。
        return ((MethodInterceptor) interceptorOrInterceptionAdvice).invoke(this);
    }
}
```

至此，我们的Spring Aop也就彻底的看完了，相信经过你自己的思考，你一定会有所感知！

------------------------------------------------------------------

好了，今天的文章到这里也就结束了，作者闲暇时间整理了一份资料，大家有兴趣可以关注公众号【`JAVA程序狗`】回复【`OMG`】领取下！

![](http://images.huangfusuper.cn/typora/asdasdasdasdcccc.png)

