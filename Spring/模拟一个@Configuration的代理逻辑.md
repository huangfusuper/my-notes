这篇文章，没有看过上一篇文章的人可能云里雾里不知道我在干什么，建议先观看文章[Spring中眼见为虚的 @Configuration 配置类](https://mp.weixin.qq.com/s/slTtgTULME6uvDh6RNq33g)再来看这个！

上周分享过一篇文章[Spring中眼见为虚的 @Configuration 配置类](https://mp.weixin.qq.com/s/slTtgTULME6uvDh6RNq33g),具体阐述了，当你使用`@Configuration`的时候Spring会对起底层做了一个什么样的逻辑，从而实现了`@Bean`的多次调用，只返回一个实例的功能！本来上篇文章打算把手写的也发出来的，但是在发的时候，因为篇幅过长被限制了，所以就拆分成两篇文章发表了！

废话补多少，我们一起模拟一个Spring对于配置类的代理问题，他是如何进行cglib的代理的呢？

## 示例代码

首先我们需要有一个类似于`@Bean`的注解，我们叫做`@MyBean`!

```java
package simulation.cglib.annotations;

import java.lang.annotation.*;

/**
 * 模仿 @Bean
 * @author huangfu
 */
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface MyBean {
}
```

然后我们写两个bean

```java
/**
 * 邮件服务
 * @author huangfu
 */
public class EmailService {

	public void sendEmail(String msg){
		System.out.println(String.format("发送成功,消息为:%s",msg));
	}
}


/**
 * 用户服务
 * @author huangfu
 */
public class UserService {
	private final EmailService emailService;


	public UserService(EmailService emailService) {
		this.emailService = emailService;
	}

	public void userSendEmail(String msg){
		emailService.sendEmail(msg);
	}
}
```

然后，我们定义一个类似于Spring的配置类，创建这两个Bean

```java
package simulation.cglib.config;

import simulation.cglib.annotations.MyBean;
import simulation.cglib.service.EmailService;
import simulation.cglib.service.UserService;

public class AppConfig {
	@MyBean
	public EmailService emailService(){
		System.out.println("-----emailService参与实例化----");
		return new EmailService();
	}

	@MyBean
	public UserService userService(){
		System.out.println("-----userService参与实例化----");
		EmailService emailService = emailService();
		return new UserService(emailService);
	}

}
```

## 拦截器的定义

重点来了，首先我们需要一个过滤器，来过滤我们关注的方法！

```java
package simulation.cglib.filter;

import org.springframework.cglib.proxy.Callback;
import org.springframework.cglib.proxy.CallbackFilter;
import simulation.cglib.callbacks.ConditionMethodInterceptor;

import java.lang.reflect.Method;

/**
 * 方法拦截器
 * @author huangfu
 */
@SuppressWarnings("all")
public class MyMethodConditionFilter implements CallbackFilter {
	private final Callback[] callbacks;
	private final Class[] callbackType;

	public MyMethodConditionFilter(Callback[] callbacks) {
		this.callbacks = callbacks;
		callbackType = new Class[callbacks.length];
		for (int i = 0; i < this.callbacks.length; i++) {
			this.callbackType[i] = this.callbacks[i].getClass();
		}
	}

	@Override
	public int accept(Method method) {
		for (int i = 0; i < this.callbacks.length; i++) {
			Callback callback = callbacks[i];
			if(!(callback instanceof ConditionMethodInterceptor) || ((ConditionMethodInterceptor)callback).isMatch(method)){
				return i;
			}
		}
		throw new RuntimeException("-------------没有可用的回调方法--------------");
	}

	public Class[] getCallbackType() {
		return callbackType;
	}
}
```

过滤器开发完成后，我们需要开发一个回调函数，熟悉Cglib的同学可能会熟悉这个，他是Cglib代理逻辑的回调函数！

```java
package simulation.cglib.callbacks;

import org.springframework.cglib.proxy.Callback;

import java.lang.reflect.Method;

/**
 * 方法拦截器条件
 * @author huangfu
 */
public interface ConditionMethodInterceptor extends Callback {

	/**
	 * 这个方法是否匹配
	 * @param candidateMethod
	 * @return
	 */
	boolean isMatch(Method candidateMethod);
}

```

```java
package simulation.cglib.callbacks;

import org.springframework.cglib.proxy.MethodInterceptor;
import org.springframework.cglib.proxy.MethodProxy;
import simulation.cglib.annotations.MyBean;
import simulation.cglib.utils.CglibUtil;

import java.lang.reflect.Method;

/**
 * 方法拦截器
 * @author huangfu
 */
public class BeanMethodInterceptor implements ConditionMethodInterceptor, MethodInterceptor {
    /**
    * 判断该方法是否匹配拦截规则
    **/
	@Override
	public boolean isMatch(Method candidateMethod) {
		return (candidateMethod.isAnnotationPresent(MyBean.class) && candidateMethod.getDeclaringClass()!=Object.class);

	}

	@Override
	public Object intercept(Object o, Method method, Object[] objects, MethodProxy methodProxy) throws Throwable {
		if(CglibUtil.checkBeanFactory(method)){
            //调用原始的逻辑
			return methodProxy.invokeSuper(o, objects);
		}
		//使用工厂方法，不在调用原始的逻辑
		return cglibProxyLogic(method);
	}

	private Object cglibProxyLogic(Method method){
		return CglibUtil.getBean(method.getName());
	}
}
```

## 开发调用工具

我们需要一个类似于 BeanDefMap的实体，来承载Bean的信息！

```java
package simulation.cglib.pojo;

import java.lang.reflect.Method;

/**
 * @author huangfu
 */
public class BeanDeMap {
	private String beanFactoryName;
	/**
	 * 原始类的class
	 */
	private Class aClass;


	private Method method;

	private Class beanFactoryClass;

	public String getBeanFactoryName() {
		return beanFactoryName;
	}

	public void setBeanFactoryName(String beanFactoryName) {
		this.beanFactoryName = beanFactoryName;
	}

	public Class getBeanFactoryClass() {
		return beanFactoryClass;
	}

	public void setBeanFactoryClass(Class beanFactoryClass) {
		this.beanFactoryClass = beanFactoryClass;
	}

	public Class getaClass() {
		return aClass;
	}

	public void setaClass(Class aClass) {
		this.aClass = aClass;
	}

	public Method getMethod() {
		return method;
	}

	public void setMethod(Method method) {
		this.method = method;
	}
}
```

创建一个工具类，调用对配置类增加代理

```java
package simulation.cglib.utils;

import org.springframework.cglib.proxy.Callback;
import org.springframework.cglib.proxy.Enhancer;
import org.springframework.cglib.proxy.NoOp;
import org.springframework.util.StringUtils;
import simulation.cglib.annotations.MyBean;
import simulation.cglib.callbacks.BeanMethodInterceptor;
import simulation.cglib.config.AppConfig;
import simulation.cglib.filter.MyMethodConditionFilter;
import simulation.cglib.pojo.BeanDeMap;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * @author huangfu
 */
@SuppressWarnings("all")
public class CglibUtil {

	/**
	 * 方法拦击回调参数
	 */
	private static final Callback[] CALLBACKS = {new BeanMethodInterceptor(), NoOp.INSTANCE};
	/**
	 * 方法本地线程变量
	 */
	public static ThreadLocal<Method> threadLocal = new ThreadLocal<>();

	/**
	 * bd Map
	 */
	private static Map<String, BeanDeMap> bdMap = new ConcurrentHashMap<>(8);

	/**
	 * 模拟单例池
	 */
	private static Map<String,Object> singMap = new ConcurrentHashMap<>(8);
	private final Class classes;

	/**
	 * 初始化环境
	 * @param classes
	 */
	public CglibUtil(Class classes) {
		this.classes = classes;
		//调用增强方法
		enhanceConfig();
		//创建bean
		createBean();
	}

	/**
	 * 创建bean
	 */
	private void createBean() {
		bdMap.forEach((key,beanDeMap) ->{
			//创建bean
			Object createBean = doCreateBean(beanDeMap);
			//放置到单例池
			singMap.put(key,createBean);
		});
	}

	/**
	 * 开始创建bean
	 * @param beanDeMap
	 * @return
	 */
	private static Object doCreateBean(BeanDeMap beanDeMap){
		try{
			//如果发现创建该bean需要 工厂方法  也就是@MyBean方法创建
			if(!StringUtils.isEmpty(beanDeMap.getBeanFactoryName())) {
				//获取对应的方法
				Method method = beanDeMap.getMethod();
				//向本地对象设置方法对象
				threadLocal.set(method);
				//反射执行增强类的方法
				Object invoke = method.invoke(singMap.get(beanDeMap.getBeanFactoryName()));
				//返回执行结果
				return invoke;
			}else{
				//普通bean直接创建
				Object resourceObject = beanDeMap.getaClass().newInstance();
				return resourceObject;
			}
		}catch (Exception e){
			e.printStackTrace();
			return null;
		}
	}

	/**
	 * 配置类增强
	 */
	private void enhanceConfig(){
		//创建一个cglib的增强器
		Enhancer enhancer = buildEnhancer();
		//获取beanName
		String beanName = classes.getSimpleName();
		//获取增强后的类的对象
		Class targetClass = enhancer.createClass();
		//注册回调方法  也就是拦截器的内部逻辑
		Enhancer.registerStaticCallbacks(targetClass,CALLBACKS);
		//创建一个BD
		BeanDeMap beanDeMap = new BeanDeMap();
		beanDeMap.setaClass(targetClass);
		//将类的信息放置到集合中
		bdMap.put(beanName,beanDeMap);
		//解析配置文件
		parseConfigClass(targetClass, beanName);
	}

	/**
	 * 解析配置类
	 * @param cglibProxyClass
	 * @param factoryName
	 */
	private void parseConfigClass(Class cglibProxyClass, String factoryName){
		//获取所有的方法
		Method[] declaredMethods = this.classes.getDeclaredMethods();
		Arrays.stream(declaredMethods).forEach(method -> {
			//获取需要加载的bean
			if(method.isAnnotationPresent(MyBean.class)){
				BeanDeMap beanDeMap = new BeanDeMap();
				String name = method.getName();
				if(bdMap.containsKey(name)) {
					throw new RuntimeException("beanName 重复");
				}
				//设置bd对的信息
				beanDeMap.setBeanFactoryName(factoryName);
				beanDeMap.setBeanFactoryClass(cglibProxyClass);
				beanDeMap.setMethod(method);
				bdMap.put(name,beanDeMap);
			}
		});
	}

	/**
	 * 构建增强器
	 * @return
	 */
	private Enhancer buildEnhancer(){
		//创建一个增强器
		Enhancer enhancer = new Enhancer();
		//设置要被代理的类
		enhancer.setSuperclass(classes);
		enhancer.setUseFactory(false);
		//构建和设置过滤器
		MyMethodConditionFilter filter = new MyMethodConditionFilter(CALLBACKS);
		enhancer.setCallbackFilter(filter);
		//设置回调类型
		enhancer.setCallbackTypes(filter.getCallbackType());
		return enhancer;
	}

	/**
	 * 验证工厂方法
	 * @param method
	 * @return
	 */
	public static boolean checkBeanFactory(Method method){
		return method.getName().equals(CglibUtil.threadLocal.get().getName());
	}

	public static Object getBean(String beanName){
		Object target = singMap.get(beanName);
		if(target == null){
			BeanDeMap beanDeMap = bdMap.get(beanName);
			target = doCreateBean(beanDeMap);
		}
		return target;
	}
}
```

## 完成测试

```java
package simulation.cglib;

import simulation.cglib.config.AppConfig;
import simulation.cglib.utils.CglibUtil;

public class CglibMainTest {
	public static void main(String[] args) {
		CglibUtil cglibUtil = new CglibUtil(AppConfig.class);

	}
}
```

记果当然是正确的

![image-20200817131248813](http://images.huangfusuper.cn/typora/0817配置类信息啊啊啊.png)

![<u>image-20200817131129607</u>](http://images.huangfusuper.cn/typora/chlibconfig自定义0817.png)

可以看到，虽然被调用了两次，但是最终只实例化了一次！

这篇文章，没有看过上一篇文章的人可能云里雾里不知道我在干什么，建议先观看文章[Spring中眼见为虚的 @Configuration 配置类](https://mp.weixin.qq.com/s/slTtgTULME6uvDh6RNq33g)再来看这个！

