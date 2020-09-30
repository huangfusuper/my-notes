## 一、循环依赖所产生的原因

在探讨Spring三级缓存解决循环引用之前，我们需要了解一点就是Spring所谓的循环依赖到底是什么，是如何产生的，为什么会产生这种问题？

![<u><u>image-20200923091530338</u></u>](http://images.huangfusuper.cn/typora/循环引用产生条件.png)

这就是经典的一个循环引用的问题，一个类的实例化依赖另外一个类，如果我们不使用Spring管理这两个bean而是自己手动创建，这种循环引用的方式实现极其简单：

![image-20200923092015113](http://images.huangfusuper.cn/typora/new解决循环引用.png)

为什么Spring解决循环依赖比较麻烦呢？因为Spring创建一个Bean是需要通过反射来构建的，构建过程中无法感知这个类具体是什么类型的，它只能够实例化一个填充一个实体！于是：

- 创建 `UserServiceImpl`完成后发现依赖`EmailServiceImpl` ！
- 于是创建`EmailServiceImpl` ，但是创建完成后又发现依赖于`UserServiceImpl`！
- 于是又去创建`UserServiceImpl`，又发现`EmailServiceImpl` ！
- 然后我又去创建`EmailServiceImpl` 
- ........

一直循环往复，从而产生了循环依赖的问题！ 由此我们循环不断的创建，从而造成了不断的死循环，此时Spring会抛出`BeanCurrentlyInCreationException`异常！ 

如何解决这个问题呢？ 循环依赖的矛盾点就在于要创建`UserServiceImpl`，它需要`EmailServiceImpl` ，而创建`EmailServiceImpl` ，又需要`UserServiceImpl`，然后两个bean都创建不出来！

## 二、如何解决循环依赖

我们可以创建两个容器（Map）,一个起名为`singletonObjects`，一个起名为`earlySingletonObjects`!

- **singletonObjects**：单例池，我们去存放已经创建完成，并且属性也注入完毕的对象！
- **earlySingletonObjects**：提前暴露的对象，存放已经创建完成，但是没有注入好的对象！

我们有了这两个Map对象，那么我们再次试图创建一个被循环依赖的bean!

- 创建 `UserServiceImpl`完成后,把自己存到**earlySingletonObjects**里面去，然后发现依赖`EmailServiceImpl` ！
- 于是试图从**singletonObjects**寻找，很显然是没有的，然后到**earlySingletonObjects**里面寻找发现也没有，开始新建！
- 创建`EmailServiceImpl` 完成后，把自己存放到**earlySingletonObjects**里面去，然后发现依赖`UserServiceImpl`！
- 于是试图从**singletonObjects**寻找，很显然是没有的，然后到**earlySingletonObjects**里面寻找，发现了`UserServiceImpl`对象！
- 将**earlySingletonObjects**返回的对象`UserServiceImpl`设置到`EmailServiceImpl` 中去，创建完成！
- 把自己放置到**singletonObjects**里面，然后把自己从**earlySingletonObjects**删除掉！返回！
- `UserServiceImpl`将返回的`EmailServiceImpl` 设置到对应的属性中，创建完成！
- 把自己放置到**singletonObjects**里面，然后把自己从**earlySingletonObjects**删除掉！返回！

至此我们解决了循环引用的问题！

由此至少，解决循环依赖，我们现在至少知道需要两个条件：

- 循环依赖的解决必须要经过反射创建对象这一步，如果你不使用属性注入，转而使用构造参数注入就会出问题，因为Spring都没有办法实例化对象，就更不要谈属性注入了！
- 循环依赖的bean必须是单例的，如果不是单例的，就会出现我们上面说的无限循环的问题！

**图例**

![image-20200923141100566](http://images.huangfusuper.cn/typora/image-20200923141100566.png)

## 三、Spring为什么使用三级缓存解决呢？

通过上面的解释我们大概明白了循环依赖的解决方案，Spring也是这样解决的，但是Spring所考虑的要比我们详细的多，我们明明采用二级缓存就能够解决循环依赖，但是Spring为什么使用了三级缓存呢？

我们先来了解一下Spring每个缓存的名字及其作用：

- **singletonObjects**：单例池，我们去存放已经创建完成，并且属性也注入完毕的对象！
- **earlySingletonObjects**：提前暴露的对象，存放已经创建完成，但是没有注入好的对象！
- **singletonFactories：**提前暴露的对象，存放已经创建完成，但是还没有注入好的对象的工厂对象！通过这个工厂可以返回这个对象！

为什么？事实上Spring循环依赖能够被众多人提起，其根本原因就是明明使用二级缓存就能够解决的问题，为什么偏偏要使用三级缓存去解决呢？

我们上面的设计方案是能够很好的解决循环依赖所带来的问题，但是请大家思考一个问题：

> 我们创建的bean所依赖的对象是一个需要被Aop代理的对象，怎么办？遇到这种情况，我们肯定不能够直接把创建完成的对象放到缓存中去的！为什么，因为我们期望的注入的是一个被代理后的对象，而不是一个原始对象！ 
>
> 所以这里并不能够直接将一个原始对象放置到缓存中，我们可以直接进行判断，如果需要Aop的话进行代理之后放入缓存！
>
> 但是，请大家想一下，上一篇复习中Aop的操作是在哪里做的？是在Spring声明周期的最后一步来做的！但是，如果我们进行判断创建的话，Aop的代理逻辑就会在创建实例的时候就进行Aop的代理了，这明显是不符合Spring对于Bean生命周期的定义的！
>
> 所以，Spring有重新定义了一个缓存【**singletonFactories**】用来存放一个Bean的工厂对象，创建的对象之后，填充属性之前会吧创建好的对象放置到【**singletonFactories**】缓存中去，并不进行实例化，只有在发生了循环引用，或者有对象依赖他的时候，他才会调用工厂方法返回一个代理对象，从而保证了Spring对于Bean生命周期的定义！

我们先看一下关于三级缓存的定义！

![image-20200923144327428](http://images.huangfusuper.cn/typora/image-20200923144327428.png)

会发现，他并不像一级缓存和二级缓存一样，放的是Bean的对象，他存放的是一个`ObjectFactory`对象，这个对象是干什么呢？我们需要继续深入！

![image-20200923144716172](http://images.huangfusuper.cn/typora/image-20200923144716172.png)

这个就是Spring三级缓存里面对`ObjectFactory`的实现！大致功能就是，遍历所有的`BeanPostProcessor`后置处理器，如果找到了`SmartInstantiationAwareBeanPostProcessor`类型的后置处理器，也就是处理Aop的后置处理器，就返回一个Aop处理后的对象，如果该类没有被代理就返回一个传入的bean！

![img](http://images.huangfusuper.cn/typora/上传循环依赖逻辑代码20200729.png)

## 四、从源码上看循环引用

首先，我们会先创建对象【**UserServiceImpl**】的时候会先从缓存中获取一下，获取到直接返回，获取不到在创建！

![image-20200923152629744](http://images.huangfusuper.cn/typora/image-20200923152629744.png)

第一次获取肯定为null，因为没有任何人往这些缓存里面放数据！ 获取到空对象之后，开始创建对象！

![image-20200923153403696](http://images.huangfusuper.cn/typora/image-20200923153403696.png)

创建对象完成之后，吧这个对象包装成工厂对象，然后放到三级缓存！

![image-20200923153700614](http://images.huangfusuper.cn/typora/image-20200923153700614.png)

然后，开始进行属性的填充【**EmailServiceImpl**】！

![image-20200923153855960](http://images.huangfusuper.cn/typora/image-20200923153855960.png)

填充过程中，调用getBean 查询缓存中是否存在需要注入的对象

![image-20200923154354974](http://images.huangfusuper.cn/typora/image-20200923154354974.png)

我们会发现，此时又回到了第一步的逻辑，也是获取不到任何对象！于是往下走，开始创建对象，然后将创建好的对象【**EmailServiceImpl**】放置到三级缓存！

然后再次开始属性注入，发现依赖【UserServiceImpl】，于是再次开始尝试用bean容器里面获取【UserServiceImpl】，于是再次走到第一步！

但是这一次和以往不同，在获取【UserSercieImpl】的时候，因为在创建的时候已经放置到了三级缓存中去，此时是能够获取到数据的！

![image-20200923154522453](http://images.huangfusuper.cn/typora/image-20200923154522453.png)

于是这个对象就被返回，注入到对应的属性，一路返回到，注入完成，初始化完成，走完整个【EmailServiceImpl】Bean的生命周期！ 然后一路返回到，创建bean的调用处！将【EmailServiceImpl】放到一级缓存里面

![image-20200923155340502](http://images.huangfusuper.cn/typora/image-20200923155340502.png)

然后再次返回这个对象，到**【UserServciceImpl】**的注入逻辑，最终**【EmailServiceImpl】**被注入到UserServiceImpl,然后UserServiceImpl也返回到创建Bean的调用处，放置到一级缓存，最终整个循环引用彻底完成！