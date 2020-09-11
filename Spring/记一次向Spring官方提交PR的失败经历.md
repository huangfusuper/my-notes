# 记一次向Spring官方提交PR的失败经历

## 一、事情始末

周末无聊在家，打开Spring源码，想再温习一遍之前学习过的流程，忽然看到一段代码，就是在执行`BeanFactoryPostProcessor`的逻辑中我发现了这样奇怪的一幕：

![事情原委](http://images.huangfusuper.cn/typora/image-20200911085433400.png)



**于是我就把代码改成这个样子（`草率了`）**

![草率了](http://images.huangfusuper.cn/typora/草率了.png)

于是乎，整个代码都简便多了，当时随手写了一个测试类，没报错就直接提交到Spring项目上了，然后申请合并了，当我怀着激动地心，颤抖的手，提交完成之后，一天我都十分亢奋，是不是的打开github，看看作者回复了我没有！

## 二、终于，草率了！

到了下午三四点左右的时间，作者回复我了（都是英文，我用谷歌给你翻译一波），截图如下：

![image-20200911090438959](http://images.huangfusuper.cn/typora/image-20200911090438959.png)

**当时我刚从公司出门，骑着我的小电驴，怎么都想不明白，为什么会被拒？为什么？**

因此，我打算着回家，和这两个人争论一番！！！

**然而，然而，我在走到回家路上的一个红绿灯的一瞬间`灵机一动、无中生有、暗度陈仓、凭空想象、凭空捏造`**，我莫名其妙的想明白了！**`是！我！错！了！`**

## 三、错误原因

中所周知，我们在`BeanFactoryPostProcessor`里面是可以修改类的`BeanDefinition`里面的属性的，假设，按照我修改的做法，遍历的时候就实例化，后面直接执行，会出现什么问题呢？看一段代码：

**假设，我现在有两个`BeanFactoryPostProcessor`**

`低级别的：`

```java
/**
 * 低级别的BeanFactoryPostProcessor
 *
 * @author huangfu
 * @date 2020年9月11日09:16:41
 */
@Component
public class MyBeanFactoryPostProcessor implements BeanFactoryPostProcessor {
	@Override
	public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
		System.out.println("我心态崩了呀！");
	}
}
```

`高级别的：`

```java
/**
 * 高级别的BeanPostProcessors
 *
 * @author huangfu
 * @date 2020年9月11日09:15:35
 */
@Component
public class PriorityOrderedBeanFactoryPostProcessors implements BeanFactoryPostProcessor, PriorityOrdered {
	@Override
	public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
		GenericBeanDefinition genericBeanDefinition = (GenericBeanDefinition) beanFactory.getBeanDefinition("myBeanFactoryPostProcessor");
		System.out.println("-----------MyBeanPostProcessors -------------------");
		//这里就是修改了myBeanFactoryPostProcessor的BeanClass 不具体写了
		genericBeanDefinition.setBeanClass(XXXXXX.class);
	}

	@Override
	public int getOrder() {
		return 0;
	}
}
```

可以看到，`高级别的修改了低级别的BeanFactoryPostProcessor`! 按照Spring原来的逻辑，

1. 先把高级别的`PriorityOrderedBeanFactoryPostProcessors`初始化了
2. 然后把低级别的beanName放到容器里面！
3. 遍历完成之后，先执行高级别的`PriorityOrderedBeanFactoryPostProcessors`,修改了低级别的`BeanDefinition`！
4. 低级别的因为值存在了一个BeanName,那么在执行之前会先去容器里面获取被高级别的修改后的`BeanDefinition`
5. 然后执行低级别的`BeanFactoryPostProcessor`,此时执行的就是被高级别修改后的逻辑！



**那么，我修改后的逻辑会出什么样的问题呢？**

我们还是按照上述代码，执行一遍我自己修改后的逻辑！

1. 先把高级别的`PriorityOrderedBeanFactoryPostProcessors`初始化了
2. 再把低级别的初始化了！
3. 执行高级别的`PriorityOrderedBeanFactoryPostProcessors`,修改了低级别的`BeanDefinition`！
4. 因为此时低级别在高级别修改之前就已经初始化完了，那么`PriorityOrderedBeanFactoryPostProcessors`的修改压根就没生效！
5. OMG，此时就出现了问题，明明我在高级别的后置处理器中做了对于低级别的后置处理器的修改，但是却莫名灭有生效，你说尴尬不！

## 四、总结

整个事情的始末就是这样，不知道你看懂了吗？

虽然这次闹了一个大乌龙吧，但是如果不是因为这一茬事，我压根不会往这上面想，总的来说，对我是有益的！哈哈哈！

大家有时候在阅读源码的时候，发现有不合理的地方，经过自己的试验之后尽管向上提，大不了不通过呗！通过一次次失败的经历，再不济也会让你对源码的掌握提升一个级别！ 好一点的话，你就能成为一些顶级开源项目的代码贡献者哦！相信这是每一个热衷技术人的追求！

好了，本期就到这里了，欢迎关注作者，`作者最近会更新一个Spring源码精读的系列文章，我会带你从头到尾的去过一遍Spring的源码！`**`欢迎关注作者【JAVA程序狗】`**

