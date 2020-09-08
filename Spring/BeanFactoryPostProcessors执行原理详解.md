了解了`BeanDefinition`以及生命周期的大概概念之后，我们班可以试着看一下源码！我们上一章也说到，`BeanFactoryPostProcessors`的执行时机是：在扫描完成之后，实例化之前！ 那么我们看一下Spring是如何去回调`BeanFactoryPostProcessors`的呢？

```java
org.springframework.context.support.AbstractApplicationContext#refresh
org.springframework.context.support.AbstractApplicationContext#invokeBeanFactoryPostProcessors
org.springframework.context.support.PostProcessorRegistrationDelegate#invokeBeanFactoryPostProcessors
    
invokeBeanFactoryPostProcessors就是扫描项目转换成BeanDefinition 然后回调BeanFactoryPostProcessors的地方！我们看源码也是从这里开始看！
```

我这里会分段截取代码进行讲解，文章末尾会复制整段代码：

### 代码一：初始化对应的集合

![image-20200908091328833](http://images.huangfusuper.cn/typora/image-20200908091328833.png)

进入到这个方法之后，

1. 我们会迎来第一个判断，也就是判断当前使用的工厂是不是`BeanDefinitionRegistry`，这个判断99%都会返回为true，为什么呢？因为除非进行了很深度的扩展Spring，自己继承整个工厂的顶级接口`AliasRegistry`去实现一个完全由自己实现的工厂，这个判断才会被跳过！这个对于我们现阶段来说，不用太过深究，我们现在就先认定一件事，我们使用的beanFactory工厂一定是 `BeanDefinitionRegistry`类型的，这个判断也一定会进来；
2. 初始化了二个集合，这二个集合各有用意，第一个集合就存放我们手动提供给Spring的后置处理器，注意这个手动，他并不是又Spring扫描得到的，而是我们自己设置进去的，当然这里是后话！
3. 第二个集合是存放执行过程中找到的`BeanDefinitionRegistryPostProcessor`,为什么要存放他呢？因为他是`BeanFactoryPostProcessor`的子类，在整个执行调用过程中，我们会先执行`BeanDefinitionRegistryPostProcessor`类型的后置处理器，在执行`BeanFactoryPostProcessor`类型的，但是因为是子类和父类的关系，为了避免后面重复的获取，就索性吧`BeanDefinitionRegistryPostProcessor`存储起来，等待`BeanDefinitionRegistryPostProcessor`的方法执行完毕之后，就直接执行他父类的方法，这也能够从侧面证明`BeanDefinitionRegistryPostProcessor`的`postProcessBeanFactory`方法是优先于`BeanFactoryPostProcessor`的`postProcessBeanFactory`方法先执行的！当然这一点我会在后面用代码进行验证！

### 代码二、遍历用户自己手动添加的后置处理器

![image-20200908092446476](http://images.huangfusuper.cn/typora/image-20200908092446476.png)

这个循环是为了循环程序员自己手动添加的后置处理器（不用太过深究，后面我会用代码说明），如果是`BeanDefinitionRegistryPostProcessor`的就先调用了，如果是`BeanFactoryPostProcessor`类型的，就先放到`regularPostProcessors`集合中，等待`BeanDefinitionRegistryPostProcessor`执行完毕后，在进行`BeanFactoryPostProcessor`的调用！

### 代码三：开始调用实现了PriorityOrdered接口的BeanDefinitionRegistryPostProcessor

![image-20200908093030287](http://images.huangfusuper.cn/typora/image-20200908093030287.png)

我们迎来了第一段比较重要的代码，首先会先去在整个bean工厂寻找`BeanDefinitionRegistryPostProcessor`类型的并且实现了类`PriorityOrdered`的类！注意此时没有任何人向beanFactory中放置该类型的类，他只有一个实现，就是Spring在开天辟地的时候初始化的几个`BeanDefinition`，其中有一个符合条件

![image-20200908093912603](http://images.huangfusuper.cn/typora/image-20200908093912603.png)

他就是`ConfigurationClassPostProcessor`,这个类是Spring初始化的时候就放置到容器里面的，他做的事情很很简单，就是解析Spring配置类，然后扫描项目，将项目内符合条件的类，比如`@Server、@Bean`之流加了注解的类，转换成`BeanDefinition`，然后存放到容器，请注意一点，此时经过`ConfigurationClassPostProcessor`的执行之后，我们Spring容器中有值了，有了我们配置的所有的应该被Spring管理的类！此时再去寻找就会寻找我们自己定义的一些后置处理器了！

### 代码四：开始调用实现了Ordered接口的BeanDefinitionRegistryPostProcessor

![image-20200908094511381](http://images.huangfusuper.cn/typora/image-20200908094511381.png)

这一段代码基本和上面的代码一样，唯一不同的就是本次寻找的是实现了`Ordered`了的接口，因为上面`ConfigurationClassPostProcessor`的执行，此时容器内部就又了我们自己定义的类信息，所以如果我们有一个类实现了BeanDefinitionRegistryPostProcessor且实现了Ordered接口，那么此时就能够被执行了！

### 代码五：开始调用剩余的BeanDefinitionRegistryPostProcessor

![image-20200908101810906](http://images.huangfusuper.cn/typora/image-20200908101810906.png)

经过上面两个实现了`PriorityOrdered`、`Ordered`接口两种`BeanDefinitionRegistryPostProcessor`之后，优先级别最高的已经执行完毕了，后续只需要去执行剩余的`BeanDefinitionRegistryPostProcessor`就可以了，但是有些读者可能会很疑惑，上面两种调用的都是一个循环就完事了，但是为什么这里需要一个死循环呢？

因为，`BeanDefinitionRegistryPostProcessor`是一个接口，在回调他的方法的时候，里面的方法可能又注册了一些`BeanDefinition`，这些`BeanDefinition`也是`BeanDefinitionRegistryPostProcessor`类型的，举个例子就像俄罗斯套娃一样，每一个里面都会进行一些注册，谁也不知道会进行套多少层，故而要进行一个死循环，只要有，就一直遍历寻找，直到执行完为止！类似于下图这样：

![image-20200908095928070](http://images.huangfusuper.cn/typora/image-20200908095928070.png)

### 代码六：开始调用BeanDefinitionRegistryPostProcessor的父类方法

![image-20200908101909970](http://images.huangfusuper.cn/typora/image-20200908101909970.png)

- 第一行代码的意思是执行`BeanDefinitionRegistryPostProcessor`的父类方法，也就是`BeanFactoryPostProcessor`的回到方法，因为`BeanDefinitionRegistryPostProcessor`是`BeanFactoryPostProcessor`类型的，为了避免重复查询就实现执行了，他的优先级高于普通的`BeanFactoryPostProcessor`!
- 第二行代码的意思是，执行用户手动添加的`BeanFactoryPostProcessor`！后面说！

### 代码七：开始寻找BeanFactoryPostProcessor

![image-20200908103447903](http://images.huangfusuper.cn/typora/image-20200908103447903.png)

这个代码逻辑不难看懂

1. 先寻找所有的`BeanFactoryPostProcessor`类
2. 初始化三个集合，实现`PriorityOrdered`的集合、实现了`Ordered`的集合、剩余的`BeanFactoryPostProcessor`集合
3. 遍历寻找到的所有的`BeanFactoryPostProcessor`类
4. 判断当 `processedBeans`集合已经存在，也就是被`BeanDefinitionRegistryPostProcessor`处理过的直接跳过，避免重复执行！
5. 如果是实现了`PriorityOrdered`接口，直接`getBean()`提前实例化后,加入到对应的集合，注意此时已经进行实例化！
6. 如果是实现了`Ordered`接口，那么吧他的名字放到对应的集合中，注意此时他没有实例化！
7. 将普通的`BeanFactoryPostProcessor`放到对应的集合，注意也没有实例化！

通过上述，我们知道了一件事，只有`PriorityOrdered`类型的`BeanFactoryPostProcessor`被实例化了，然后放置到了集合中去！

### 代码八：开始执行BeanFactoryPostProcessor

![image-20200908102912853](http://images.huangfusuper.cn/typora/image-20200908102912853.png)

- 我们先对实现了`PriorityOrdered`的集合进行排序后执行，注意，因为上面在添加到集合的时候已经通过i`getBean()`实例化了，所以，此时可以直接执行！
- 遍历实现了`Ordered`的beanName集合，然后通过`getBean`,实例化对应的`BeanFactoryPostProcessor`,放到对应的集合`orderedPostProcessors`，排序后进行执行！
- 遍历剩余的`BeanFactoryPostProcessor`,然后`getBean`实例化后，直接执行！

### 代码流程图

![4576](http://images.huangfusuper.cn/typora/4576.png)

### 完整的代码：

```java
/**
	 * 扫描项目
	 * 调用BeanDefinitionRegistryPostProcessor 将对应的类转成BeanDefinition
	 * 调用 BeanFactoryPostProcessors的回调方法
	 * @param beanFactory bean工厂
	 * @param beanFactoryPostProcessors 手动提供的后置处理器
	 */
public static void invokeBeanFactoryPostProcessors(ConfigurableListableBeanFactory beanFactory, List<BeanFactoryPostProcessor> beanFactoryPostProcessors) {

    // 如果有的话，首先调用BeanDefinitionRegistryPostProcessors。
    Set<String> processedBeans = new HashSet<>();
    //默认使用的是DefaultListableBeanFactory工厂对象 所以i这个判断一定会进入进来
    if (beanFactory instanceof BeanDefinitionRegistry) {
        //事实上就是Bean工厂
        BeanDefinitionRegistry registry = (BeanDefinitionRegistry) beanFactory;
        //存放程序员自己手动提供给Spring的后置处理器
        List<BeanFactoryPostProcessor> regularPostProcessors = new ArrayList<>();
        //存放执行该过程中寻找到的 BeanDefinitionRegistryPostProcessor
        List<BeanDefinitionRegistryPostProcessor> registryProcessors = new ArrayList<>();

        //循环遍历bean工厂后处理器 但是这个的debug的对象确实为Null不知道为什么  事实上它并不会进入到这里
        //这个是扫描用户自己手动添加的一些BeanFactoryPostProcessors
        //事实上 我们很少会对这里进行更改，只有在对接或者开发第三方组件的时候可能会手动的设置一个后置处理器
        //正常情况下极少能够使用到这种情况
        for (BeanFactoryPostProcessor postProcessor : beanFactoryPostProcessors) {
            //这个判断就是为了保证spring自己的扫描处理器先执行  因为此时spring还没有完成扫描
            if (postProcessor instanceof BeanDefinitionRegistryPostProcessor) {
                BeanDefinitionRegistryPostProcessor registryProcessor = (BeanDefinitionRegistryPostProcessor) postProcessor;
                registryProcessor.postProcessBeanDefinitionRegistry(registry);
                registryProcessors.add(registryProcessor);
            }
            else {
                //自己定义的内助处理器
                regularPostProcessors.add(postProcessor);
            }
        }

        // 不要在这里初始化FactoryBeans：我们需要保留所有常规bean
        // 未初始化，让Bean工厂后处理器对其应用！
        // 在实现的BeanDefinitionRegistryPostProcessor之间分开
        // PriorityOrdered，Ordered和其他。
        List<BeanDefinitionRegistryPostProcessor> currentRegistryProcessors = new ArrayList<>();

        // 首先，调用实现PriorityOrdered(排序接口)的BeanDefinitionRegistryPostProcessors。 这是获取内置bean工厂后置处理器的beanName
        //查出所有实现了BeanDefinitionRegistryPostProcessor接口的bean名称
        //调用了一次BeanDefinitionRegistryPostProcessor子类  PriorityOrdered
        //获取 BeanDefinitionRegistryPostProcessor 的子类 事实上 这里只有一个叫做  ConfigurationClassPostProcessor 他实现了 PriorityOrdered接口
        //BeanFactoryPostProcessor 也就是 ConfigurationClassPostProcessor 会被添加到容器里面
        String[] postProcessorNames = beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
        for (String ppName : postProcessorNames) {
            //判断当前这个类是不是实现了PriorityOrdered接口
            if (beanFactory.isTypeMatch(ppName, PriorityOrdered.class)) {
                //getBean会提前走生命周期
                currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
                //将这个已经处理过的添加到集合里面
                //为什么要天机哀悼集合里面呢？因为本身他就属于 BeanDefinitionRegistryPostProcessor 是 BeanFactoryPostProcessor的子类
                //那么肯定 在执行BeanFactoryPostProcessor的回调的时候，他还会再次的被获取执行
                //索性 Spring为了节省效率，避免这部分 BeanDefinitionRegistryPostProcessor类被重复 获取，就在完全调用了BeanDefinitionRegistryPostProcessor类之后
                //将这一部分的接口直接给执行了也就是BeanDefinitionRegistryPostProcessor的BeanFactoryPostProcessor的回调方法是优先于直接实现BeanFactoryPostProcessor方法的
                //既然在执行BeanFactoryPostProcessor之前就执行了对应的方法回调，那么肯定，执行BeanFactoryPostProcessor的时候要把之前已经执行过的过滤掉
                //故而会将BeanDefinitionRegistryPostProcessor存储起来，后续执行BeanFactoryPostProcessor会跳过集合里面的类
                processedBeans.add(ppName);
            }
        }
        sortPostProcessors(currentRegistryProcessors, beanFactory);
        //见该处理器添加到对应的已注册集合里面 方面后面直接回调他们的父类方法也就是  BeanFactoryPostProcessors方法
        registryProcessors.addAll(currentRegistryProcessors);
        //调用Bean定义注册表后处理器  这里是真正的读取类的bd的一个方法 ConfigurationClassPostProcessor 第一次调用beanFactory 后置处理器
        //这里调用ConfigurationClassPostProcessor后置处理器会注册一个后置处理器，下面进行回调
        invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry);
        //清空当前这个处理器
        currentRegistryProcessors.clear();

        // 接下来，调用实现Ordered的BeanDefinitionRegistryPostProcessors。   Ordered
        postProcessorNames = beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
        for (String ppName : postProcessorNames) {
            //判断当前这个类是不是实现了Ordered接口
            if (!processedBeans.contains(ppName) && beanFactory.isTypeMatch(ppName, Ordered.class)) {
                //getBean会提前走生命周期
                currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
                processedBeans.add(ppName);
            }
        }
        sortPostProcessors(currentRegistryProcessors, beanFactory);
        //见该处理器添加到对应的已注册集合里面 方面后面直接回调他们的父类方法也就是  BeanFactoryPostProcessors方法
        registryProcessors.addAll(currentRegistryProcessors);
        //调用当前的BeanDefinitionRegistryPostProcessor 回调方法
        invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry);
        //清空当前这个处理器
        currentRegistryProcessors.clear();

        // 最后，调用所有其他BeanDefinitionRegistryPostProcessor，直到没有其他的出现。
        boolean reiterate = true;
        //这里为什么是死循环呢？
        //因为 BeanDefinitionRegistryPostProcessor 本身进行回调的时候会手动注册一些特殊的类，例如再次注册一个BeanDefinitionRegistryPostProcessor
        //类，可能手动注册的类里面还有，像套娃一样，故而需要进行不断的循环迭代获取，从而达到遍历全部的 BeanDefinitionRegistryPostProcessor的目的
        while (reiterate) {
            reiterate = false;
            //获取所有的BeanDefinitionRegistryPostProcessor接口的实现类
            postProcessorNames = beanFactory.getBeanNamesForType(BeanDefinitionRegistryPostProcessor.class, true, false);
            //遍历这些BeanDefinitionRegistryPostProcessor类
            for (String ppName : postProcessorNames) {
                //如果它不存在与这个集合里面，证明没有被上面处理过，就不会被跳过，这里主要是解决重复执行的情况
                if (!processedBeans.contains(ppName)) {
                    //添加到对应的当前处理器集合里面
                    currentRegistryProcessors.add(beanFactory.getBean(ppName, BeanDefinitionRegistryPostProcessor.class));
                    //添加到已处理集合里面
                    processedBeans.add(ppName);
                    //将扫描标识为true 准备下次执行
                    reiterate = true;
                }
            }
            //排序
            sortPostProcessors(currentRegistryProcessors, beanFactory);
            //注册到注册集合里面，便于后修直接回调父类
            registryProcessors.addAll(currentRegistryProcessors);
            //开始执行这些方法
            invokeBeanDefinitionRegistryPostProcessors(currentRegistryProcessors, registry);
            //清空本次执行的处理集合
            currentRegistryProcessors.clear();
        }

        // 现在，调用到目前为止已处理的所有处理器的postProcessBeanFactory回调。
        //BeanDefinitionRegistryPostProcessor 是 BeanFactoryPostProcessor
        //目的就是为了避免重复获取
        invokeBeanFactoryPostProcessors(registryProcessors, beanFactory);
        //常规的 普通的工厂后置处理器
        //程序员手动提供给Spring的BeanFactory  beanFactory.addBeanFactoryPostProcessor(new MyBeanFactoryPostProcessor())
        invokeBeanFactoryPostProcessors(regularPostProcessors, beanFactory);
    } else {
        // 调用在上下文实例中注册的工厂处理器。
        invokeBeanFactoryPostProcessors(beanFactoryPostProcessors, beanFactory);
    }

    // 不要在这里初始化FactoryBeans：我们需要保留所有常规bean
    // 未初始化，让Bean工厂后处理器对其应用！
    //这里是真正获取容器内部所有的beanFactory的后置处理器
    String[] postProcessorNames = beanFactory.getBeanNamesForType(BeanFactoryPostProcessor.class, true, false);

    List<BeanFactoryPostProcessor> priorityOrderedPostProcessors = new ArrayList<>();
    List<String> orderedPostProcessorNames = new ArrayList<>();
    List<String> nonOrderedPostProcessorNames = new ArrayList<>();
    for (String ppName : postProcessorNames) {
        //上面是否已经被执行过了，执行过的直接跳过
        if (processedBeans.contains(ppName)) {
            // skip - already processed in first phase above
        }
        //添加 实现了PriorityOrdered的BeanFactoryPostProcessors
        else if (beanFactory.isTypeMatch(ppName, PriorityOrdered.class)) {
            priorityOrderedPostProcessors.add(beanFactory.getBean(ppName, BeanFactoryPostProcessor.class));
        }
        //添加 实现了Ordered的BeanFactoryPostProcessors
        else if (beanFactory.isTypeMatch(ppName, Ordered.class)) {
            orderedPostProcessorNames.add(ppName);
        }
        else {
            //添加剩余的
            nonOrderedPostProcessorNames.add(ppName);
        }
    }

    // 首先，调用实现PriorityOrdered的BeanFactoryPostProcessors。
    sortPostProcessors(priorityOrderedPostProcessors, beanFactory);
    //首先回调实现了PriorityOrdered的BeanFactoryPostProcessors
    invokeBeanFactoryPostProcessors(priorityOrderedPostProcessors, beanFactory);

    // 接下来，调用实现Ordered的BeanFactoryPostProcessors。
    List<BeanFactoryPostProcessor> orderedPostProcessors = new ArrayList<>();
    for (String postProcessorName : orderedPostProcessorNames) {
        //getBean可以进行提前实例化进入生命周期
        orderedPostProcessors.add(beanFactory.getBean(postProcessorName, BeanFactoryPostProcessor.class));
    }
    sortPostProcessors(orderedPostProcessors, beanFactory);
    // 接下来，调用实现Ordered的BeanFactoryPostProcessors。
    invokeBeanFactoryPostProcessors(orderedPostProcessors, beanFactory);

    //最后，调用所有其他BeanFactoryPostProcessors。
    List<BeanFactoryPostProcessor> nonOrderedPostProcessors = new ArrayList<>();
    for (String postProcessorName : nonOrderedPostProcessorNames) {
        //getBean可以进行提前实例化进入生命周期
        nonOrderedPostProcessors.add(beanFactory.getBean(postProcessorName, BeanFactoryPostProcessor.class));
    }
    //这里执行的自定义的bean工厂的后置处理器
    invokeBeanFactoryPostProcessors(nonOrderedPostProcessors, beanFactory);

    // 清除缓存的合并bean定义，因为后处理器可能具有修改了原始元数据，例如替换值中的占位符...
    beanFactory.clearMetadataCache();
}
```



