## 一、概述

长文警告，事实上我不愿意写太长的文章，一面是太冗余，一方面读者容易疲倦，但是只要是涉及到源码级别的，就肯定篇幅不短，因为太短肯定没意义也解释不清楚，但是相信，耐心看完这个文章一定会有所收获！

最近有很多读者面试的时候都被问到了有关于Spring三级缓存的解决方案，很多读者在面试受挫之后，试着自己去读源码，试着去跟断点又发现一层套一层，一会自己就懵了，我这几天总结了一下，为了能够让读者更加的去了解Spring解决循环依赖问题，我决定从以下四个方面去讲述：

1. **什么是循环依赖**
2. **如果不依赖于Spring自己解决循环依赖如何解决？**
3. **自己实现的方式有什么缺陷？**
4. **Spring中是如何解决循环依赖的？**

## 二、什么是循环依赖

循环依赖直白点就是发生在两个类，`你引用我，我引用你`的状态，如图：

![循环依赖示意图](http://images.huangfusuper.cn/typora/0729循环依赖示意图1.png)

## 三、如果不依赖于Spring自己解决循环依赖如何解决

以上图为例，假设，我们能够创建完成`AService`之后，放置到到一个缓存中，再去注入属性！每次注入属性的时候，所需要的属性值都从缓存中获取一遍，缓存中没有再去创建不就解决了？如图所示：

![](http://images.huangfusuper.cn/typora/自己解决循环依赖07292020.png)

总结一下上面的流程：

1. `AService`创建完成后将自己加入到二级缓存，然后开始注入属性
2. 发现`AService`依赖`BService`于是先查询一级缓存是否有数据一级缓存没有就查询二级缓存，有就返回，没有就创建`BService`
3. 缓存中没有，开始实例化`BService`，然后注入内部属性！
4. 注入内部属性时发现依赖`AService`，于是先查询一级缓存是否有数据一级缓存没有就查询二级缓存，有就返回，没有就创建，很显然，二级缓存是有数据的。于是从二级缓存取出`AService`注入到`BService`。
5. `BService`创建完成后将自己从二级缓存挪到一级缓存，并返回。
6. `AService`获取到`BService`后，注入到自己的属性中并把自己从二级缓存挪的一级缓存，返回`AService`!
7. 至此，循环依赖创建完成！

那么有了上面的思路，我们如何用代码实现一遍我们的逻辑呢？

## 四、如果不依赖于Spring自己解决循环依赖如何解决

**首先，我么肯定要定义一个类似于`@Autowired`这样的注解，这里我们叫做    `@MyAutowired`**

```java
package simulation.annotations;

import java.lang.annotation.*;

/**
 * 自定义注入注解 相当于 Spring的@Autowired
 * @author huangfu
 */
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.FIELD)
@Inherited
public @interface MyAutowired {
}
```

**然乎我们需要模拟一个循环引用**

```java
package simulation.service;

import simulation.annotations.MyAutowired;

public class AService {
    @MyAutowired
    private BService bService;
}
```

```java
package simulation.service;

import simulation.annotations.MyAutowired;

public class BService {

    @MyAutowired
    private AService aService;
}
```

以上，我们定义了一个循环引用，`AService`引用`BService`；而且`BService`引用`AService`,标准的循环引用

**然后，我们就根据（三）说的思路，我们去用代码解决**

```java
package simulation;

import simulation.annotations.MyAutowired;
import simulation.service.AService;

import java.lang.reflect.Field;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 模拟Spring解决循环依赖的问题
 * @author huangfu
 */
public class DebugTest {

    /**
     * 已经完全创建好的
     */
    private final Map<String,Object> singletonObject = new HashMap<>(8);
    /**
     * 创建一半但是没有属性注入的
     */
    private final Map<String,Object> earlySingletonObjects = new HashMap<>(8);

    public static void main(String[] args) throws IllegalAccessException, InstantiationException {
        DebugTest debugTest = new DebugTest();
        AService bean = debugTest.getBean(AService.class);
        System.out.println(bean);
    }

    /**
     * 获取一个bean对象
     * @param tClass
     * @return
     */
    public <T> T getBean(Class<T> tClass) throws InstantiationException, IllegalAccessException {
        //先查询一级缓存是否有数据
        String beanName = getBeanName(tClass);
        Object object = singletonObject.get(beanName);
        //一级缓存没有在查询二级缓存是否有数据
        if(object == null){
            object = earlySingletonObjects.get(beanName);
            if(object == null) {
            	//两个缓存都没有就创建类
                object = createBean(tClass,beanName);
            }
        }
        return (T)object;
    }

    /**
     * 创建一个bean
     * @param tClass
     * @param beanName
     * @return
     */
    public Object createBean(Class<?> tClass,String beanName) throws IllegalAccessException, InstantiationException {
        //反射创建对象
        Object newInstance = tClass.newInstance();
        //实例化完就放到二级缓存
        earlySingletonObjects.put(beanName,newInstance);
        //开始填充属性
        populateBean(newInstance);
        //填充完成后从创作中的集合转移到完全体集合
        earlySingletonObjects.remove(beanName);
        singletonObject.put(beanName,newInstance);
        return newInstance;
    }

    /**
     * 填充属性
     */
    public void populateBean(Object object) throws InstantiationException, IllegalAccessException {
    	//获取所有添加了 @MyAutowired 注解的属性
        List<Field> autowiredFields = getAutowiredField(object.getClass());
        for (Field field : autowiredFields) {
        	//开始注入
            doPopulateBean(object, field);
        }
    }

    /**
     * 开始注入对象
     * @param object
     * @param field
     */
    public void doPopulateBean(Object object, Field field) throws IllegalAccessException, InstantiationException {
    	//重新调用获取逻辑
        Object target = getBean(field.getType());
        field.setAccessible(true);
        //反射注入
        field.set(object,target);
    }

    /**
     * 获取被标识自动注入的属性
     * @param tClass
     * @return
     */
    private List<Field> getAutowiredField(Class<?> tClass){
        Field[] declaredFields = tClass.getDeclaredFields();
        return Arrays.stream(declaredFields).filter(field ->
                               ield.isAnnotationPresent(MyAutowired.class)).collect(Collectors.toList());
    }
    /**
     * 获取类名称
     * @param tClass
     * @return
     */
    public String getBeanName(Class<?> tClass){
        return tClass.getSimpleName();
    }
}
```

**结果**

![image-20200729225238673](http://images.huangfusuper.cn/typora/手写循环依赖解决方案运行结果20200729.png)

由上面的结果图示，我们解决了循环依赖，事实上Spring的解决方案，和我们手写的类似，但是Spring作为一个生态，它的设计和编码也是考虑的极其周全的，我们这样写虽然和Spring的最初想法时类似的，但是会出现哪些问题呢？

## 五、自己实现的方式有什么缺陷？

我们现在是直接注入类的对象，假设我们换了一种逻辑，如果我们注入的目标对象，是一个需要被代理的对象（比如该方法被AOP代理），我们这种写法就无能为力了，当然我们可以再创建的时候进行判断是否需要增加代理，当然这是一种方案，但是对于Spring而言，他的初衷是希望在bean生命周期的最后几步才去aop，再注入的时候就把该对象的代理逻辑给做完了，很显然不符合它的设计理念，那么Spring到底是如何解决的呢？

## 六、Spring中是如何解决循环依赖的？

首先，我们需要找到类再哪里实例化的，因为只有实例化了，才会执行注入的逻辑！

**入口方法：**

**org.springframework.context.support.AbstractApplicationContext#finishBeanFactoryInitialization**

**org.springframework.beans.factory.support.DefaultListableBeanFactory#preInstantiateSingletons**

```java
	@Override
	public void preInstantiateSingletons() throws BeansException {
		//遍历一个副本以允许使用init方法，这些方法依次注册新的bean定义。
		//尽管这可能不是常规工厂引导程序的一部分，但可以正常运行。
		//这里获取所有的bean name
		List<String> beanNames = new ArrayList<>(this.beanDefinitionNames);

		// 触发所有非惰性单例bean的初始化...
		for (String beanName : beanNames) {
			//获取该类的详细定义
			RootBeanDefinition bd = getMergedLocalBeanDefinition(beanName);
			//实例化条件 第一不是抽象的类  第二是单例的类  第三不是懒加载的类
			if (!bd.isAbstract() && bd.isSingleton() && !bd.isLazyInit()) {
				//哦吼  这里引申出来一个概念 当这个bean集成了beanname那么就不再走bean生命周期的实例化了 直接创建
				if (isFactoryBean(beanName)) {
					....忽略不必要代码，正常bean的初始化不会走这里...
				} else {
					//普通的bean  这里就是再创建Spring bean的实体对象的，这里也是我们探究最重要的一个逻辑
					getBean(beanName);
				}
			}
		}
        ......忽略忽略.....
    }
}
```

进入到getBean --> doGetBean

```java
protected <T> T doGetBean(final String name, @Nullable final Class<T> requiredType,
			@Nullable final Object[] args, boolean typeCheckOnly) throws BeansException {

		final String beanName = transformedBeanName(name);
		Object bean;

		// 检查单例缓存是否有手动注册的单例。
		//检查一级缓存内是否有该单例bean的对象
		//当一级缓存没有 而却当前的bean为创建中的状态时（实例化完成但是没有初始化），检查二级缓存对象，有就返回
		//当二级缓存没有 检查三级缓存，调用三级缓存的匿名内部类的回调方法获取bean对象，放置到二级缓存，删除三级缓存的该数据  返回当前bean
		//从三级缓存取的原因是因为如果该类为依赖类，并且被设置了代理，则再该方法内部获取的就是代理对象，保证注入时，第一次获取的就是一个代理对象
		//事实上 如果是循环引用，被引用对象再注入属性时三级缓存已经存在，就会使用三级缓存的工厂对象，返回该bean该做代理的时候做代理，没代理的话直接返回
		Object sharedInstance = getSingleton(beanName);
		//当发生循环依赖时，第一次查询该对象返回的数据一定为null
		if (sharedInstance != null && args == null) {
			....忽略不必要代码....
		} else {
			....忽略不必要代码....
			try {
				final RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
				....忽略不必要代码,这里主要做一些判断，比如实例化时的依赖（@dependsOn）等....

				// 创建bean实例。 这个是个真正的创建bean实例的方法   单例池获取，没有的话就将该bean加入到正在创建  然后走创建bean的回调
				if (mbd.isSingleton()) {
                    //这个方法很重要，方法内部会做这样几件事：
					//1.判断当前的一级缓存里面有没有bean
					//2.没有就回调java8里面的回调方法(createBean)创建方法，添加到一级缓存，返回bean
					//3.一级缓存存在就直接返回该bean
					sharedInstance = getSingleton(beanName, () -> {
						try {
							//这里是真正的创建bean的逻辑，由 {@link #getSingleton} 方法回调该对象去走真正的执行创建bean的逻辑
							return createBean(beanName, mbd, args);
						}
						catch (BeansException ex) {
							// 从单例缓存中显式删除实例：它可能已经放在那里
							// 急于通过创建过程，以允许循环引用解析。
							// 还删除所有收到对该bean的临时引用的bean。
							destroySingleton(beanName);
							throw ex;
						}
					});
					bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
				} else if (mbd.isPrototype()) {
					....忽略不必要代码....
				} else {
					....忽略不必要代码....
				}
			}
			catch (BeansException ex) {
				cleanupAfterBeanCreationFailure(beanName);
				throw ex;
			}
		}

		if (requiredType != null && !requiredType.isInstance(bean)) {
			....忽略不必要代码....
		}
		return (T) bean;
	}
```

- 进入到createBean里面

```java
protected Object createBean(String beanName, RootBeanDefinition mbd, @Nullable Object[] args)
                                                                                throws BeanCreationException {
   ....忽略不必要代码....
   try {
      //真正干活的方法来了  呵呵呵呵   反射创建bean
      Object beanInstance = doCreateBean(beanName, mbdToUse, args);
      //....忽略不必要代码....
      return beanInstance;
   }
   catch (BeanCreationException | ImplicitlyAppearedSingletonException ex) {
      //先前检测到的具有正确的bean创建上下文的异常，
      //或非法的单例状态，最多可以传达给DefaultSingletonBeanRegistry。
      throw ex;
   }
   catch (Throwable ex) {
      throw new BeanCreationException(
            mbdToUse.getResourceDescription(), beanName, "Unexpected exception during bean creation", ex);
   }
}
```

- 进入到doCreateBean里面

```java
protected Object doCreateBean(final String beanName, final RootBeanDefinition mbd, final @Nullable Object[] args)
			throws BeanCreationException {

		// 实例化bean。
		BeanWrapper instanceWrapper = null;
		if (mbd.isSingleton()) {
			instanceWrapper = this.factoryBeanInstanceCache.remove(beanName);
		}
		if (instanceWrapper == null) {
			//开始创建bean 的逻辑  这里实际上该类已经被实例化了 只不过返回的是一个包装对象，包装对象内部存在该实例化好的对象
			instanceWrapper = createBeanInstance(beanName, mbd, args);
		}
		//获取之前创建的bean
		final Object bean = instanceWrapper.getWrappedInstance();
    
		....忽略不必要代码....
 
        //判断当前这个对象是不是单例   是不是支持循环引用  是不是正在创建中 满足这几个条件才会放置到三级缓存
		boolean earlySingletonExposure = (mbd.isSingleton() && this.allowCircularReferences 
                                          &&isSingletonCurrentlyInCreation(beanName));
		if (earlySingletonExposure) {
			....忽略不必要代码....
                
			//这个方法时将当前实例号的bean放置到三级缓存 三级缓存内部存放的时 beanName -> bean包装对象  这个样的kv键值对
			//设置这个方法的目的时 Spring设计时是期望Spring再bean实例化之后去做代理对象的操作，而不是再创建的时候就判断是否是代理对象
			//但实际上如果发生了循环引用的话，被依赖的类就会被提前创建出来，并且注入到目标类中，为了保证注入的是一个实际的代理对象
            //所以Spring来了个偷天换日，偷梁换柱
			//后续需要注入的时候，只需要通过工厂方法返回数据就可以了，在工厂里面可以做代理相关的操作，执行完代理操作后，在返回对象
			//符合了Spring设计时，为了保证代理对象的包装再Springbean生命周期的后几步来实现的预期
			//这一步还会删除二级缓存的数据
			addSingletonFactory(beanName, () -> getEarlyBeanReference(beanName, mbd, bean));
		}

		// 初始化bean实例。
		Object exposedObject = bean;
		try {
			//填充内部的属性
			//这一步解决了循环依赖的问题，在这里发生了自动注入的逻辑
			populateBean(beanName, mbd, instanceWrapper);
			//执行初始化的逻辑  以及生命周期的回调
			exposedObject = initializeBean(beanName, exposedObject, mbd);
		}
		catch (Throwable ex) {
			....忽略不必要代码....
		}

		if (earlySingletonExposure) {
			....忽略不必要代码....
		}
		....忽略不必要代码....
		return exposedObject;
	}
```

- 进入到 populateBean方法，这里执行属性注入，同时也解决了循环依赖！

```java
protected void populateBean(String beanName, RootBeanDefinition mbd, @Nullable BeanWrapper bw) {
		....忽略不必要代码....

		// 给任何InstantiationAwareBeanPostProcessors修改机会，
		// 设置属性之前Bean的状态。例如，可以使用它
		// 支持场注入方式。
		boolean continueWithPropertyPopulation = true;

		if (!mbd.isSynthetic() && hasInstantiationAwareBeanPostProcessors()) {
			for (BeanPostProcessor bp : getBeanPostProcessors()) {
				....忽略不必要代码....
			}
		}

		if (!continueWithPropertyPopulation) {
			return;
		}
		....忽略不必要代码....
		if (hasInstAwareBpps) {
			if (pvs == null) {
				pvs = mbd.getPropertyValues();
			}
			for (BeanPostProcessor bp : getBeanPostProcessors()) {
				if (bp instanceof InstantiationAwareBeanPostProcessor) {
					InstantiationAwareBeanPostProcessor ibp = (InstantiationAwareBeanPostProcessor) bp;
					//因为是使用@Autowired注解做的自动注入
					// 故而Spring会使用 AutowiredAnnotationBeanPostProcessor.postProcessProperties来处理自动注入
                    //事实上这一步是会做注入处理的，这个也是我们重点观察的对象
					PropertyValues pvsToUse = ibp.postProcessProperties(pvs, bw.getWrappedInstance(), beanName);
					....忽略不必要代码....
				}
			}
		}
		if (needsDepCheck) {
			....忽略不必要代码....
		}

		if (pvs != null) {
			//开始设置属性值  mbd是依赖的bean
			applyPropertyValues(beanName, mbd, bw, pvs);
		}
	}
```

- 进入到 `AutowiredAnnotationBeanPostProcessor.postProcessProperties`

```java
	@Override
	public PropertyValues postProcessProperties(PropertyValues pvs, Object bean, String beanName) {
		....忽略不必要代码....
		try {
			//注入逻辑
			metadata.inject(bean, beanName, pvs);
		} catch (BeanCreationException ex) {
			throw ex;
		} catch (Throwable ex) {
			throw new BeanCreationException(beanName, "Injection of autowired dependencies failed", ex);
		}
		return pvs;
	}
```

- 进入到`inject`

```java
public void inject(Object target, @Nullable String beanName, @Nullable PropertyValues pvs) throws Throwable {
    Collection<InjectedElement> checkedElements = this.checkedElements;
    Collection<InjectedElement> elementsToIterate = (checkedElements != null ? checkedElements : this.injectedElements);
    if (!elementsToIterate.isEmpty()) {
        for (InjectedElement element : elementsToIterate) {
            if (logger.isTraceEnabled()) {
                logger.trace("Processing injected element of bean '" + beanName + "': " + element);
            }
            //注入逻辑发生的实际代码 因为是属性注入，所以 使用AutowiredFieldElement.inject
            element.inject(target, beanName, pvs);
        }
    }
}
```

- 进入到`org.springframework.beans.factory.annotation.AutowiredAnnotationBeanPostProcessor.AutowiredFieldElement#inject`

```java
protected void inject(Object bean, @Nullable String beanName, @Nullable PropertyValues pvs) throws Throwable {
    //获取需要注入的属性对象
    Field field = (Field) this.member;
    Object value;
    ......忽略不必要代码......
    else {
        ......忽略不必要代码......
        try {
            //真正的解决依赖的代码，查找依赖创建依赖的代码
            value = beanFactory.resolveDependency(desc, beanName, autowiredBeanNames, typeConverter);
        }
        catch (BeansException ex) {
            throw new UnsatisfiedDependencyException(null, beanName, new InjectionPoint(field), ex);
        }
        ......忽略不必要代码......
    }
    if (value != null) {
        //反射的注入逻辑
        ReflectionUtils.makeAccessible(field);
        field.set(bean, value);
    }
}
```

- 此时别说你们我都想说一句`wo cao`终于看到希望了，这里由 `beanFactory.resolveDependency`获取即将要注入的对象，然后后面通过反射注入到对象里面去，我们是不是只需要知道 `beanFactory.resolveDependency`里面的逻辑就可以知道循环依赖的问题了？我们果断进去看看果然发现还没完：

```java
public Object resolveDependency(DependencyDescriptor descriptor, @Nullable String requestingBeanName,
			@Nullable Set<String> autowiredBeanNames, @Nullable TypeConverter typeConverter) throws BeansException {
			......忽略不必要代码......
			if (result == null) {
				//解决依赖性 这个是实际干活的方法
				result = doResolveDependency(descriptor, requestingBeanName, autowiredBeanNames, typeConverter);
			}
			return result;
		}
	}
```

进入到 `doResolveDependency`

```java
@Nullable
	public Object doResolveDependency(DependencyDescriptor descriptor, @Nullable String beanName,
			@Nullable Set<String> autowiredBeanNames, @Nullable TypeConverter typeConverter) throws BeansException {

		    ......忽略不必要代码......
			//根据类型和名称查询该bean的数据
			Map<String, Object> matchingBeans = findAutowireCandidates(beanName, type, descriptor);
			......忽略不必要代码......
			//这一步是真正创建一个类这里面会调用getBean方法重新的走上面的那一套创建bean的逻辑
			if (instanceCandidate instanceof Class) {
				instanceCandidate = descriptor.resolveCandidate(autowiredBeanName, type, this);
			}
			......忽略不必要代码......
			return result;
		}
		......忽略不必要代码......
	}
```

- 恭喜你熬到头了，我们进入到 `descriptor.resolveCandidate(autowiredBeanName, type, this)`方法：

> org.springframework.beans.factory.config.DependencyDescriptor#resolveCandidate

```java
public Object resolveCandidate(String beanName, Class<?> requiredType, BeanFactory beanFactory)
			throws BeansException {

    return beanFactory.getBean(beanName);
}
```

哦吼，`gentBean` ，相信大家一定失忆了，你是不是在哪见过? 想想入口方法，里面是不是也是一个getBean，没错，他们俩是同一个方法，你会发现，最终需要注入的属性也会走一遍上述的逻辑从而完成属性对象的创建和获取，从而完成整个循环依赖！借用[YourBatman](https://me.csdn.net/f641385712)大佬的一张图，总结一下整个解决三级缓存的逻辑

## 七、总结

![img](http://images.huangfusuper.cn/typora/上传循环依赖逻辑代码20200729.png)

读者可以参考着上述的源码逻辑实现对比看印象更深！

本次我们先自定义实现了一个解决循环依赖的方案，然后分析了一下缺陷，然后对比Spring源码的解决方案，相信，读到这里，屏幕前的你一定有所收获！加油！