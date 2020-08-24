# 牛逼哄哄的Spring是怎么被MyBatis给征服了?

其实前几篇文章已经写了好多有关于Spring源码的文章，事实上，很多同学虽然一直在跟着阅读、学习这些Spring的源码教程，但是一直都很迷茫，这些Spring的源码学习，似乎只是为了面试吹逼用，我大概问过一些同学，很多同学看了很长时间的Spring但是依旧不知道如何将这些学到的知识运用到实际的案例上！

其实这个问题很好解决，如果你在开发中很少能够遇见需要Spring扩展时，不妨把目光放到一些依托于Spring的项目，看看它们是如何运用Spring的扩展点的。对于Spring的学习，我认为最终真正学会的一定是在某一天，Spring本身功能不够，其他框架解决不了，你能够使用自身所学，扩展Spring的实现，从而完成一些特定的功能，我愿称之为`牛逼`！

## 一、你一定用到过的 MyBatis-Spring

我个人而言，是十分喜欢MyBatis的开发者的，为什么呢？不光是因为他的功能强大，更多的是因为其开发团队的`良心`！为什么这么说呢？感兴趣的小伙伴可以进入的MyBatis-Spring的源码中，你会发现一件事，MyBatis-Spring并不是由Spring进行开发的，而是MyBatis自己进行开发的！为什么呢？看一下官方的说法：

>Spring 2.0 只支持 iBatis 2.0。那么，我们就想将 MyBatis3 的支持添加到 Spring 3.0 中（参见 Spring Jira 中的[问题](https://jira.springsource.org/browse/SPR-5991)）。不幸的是，Spring 3.0 的开发在 MyBatis 3.0 官方发布前就结束了。由于 Spring 开发团队不想发布一个基于未发布版的 MyBatis 的整合支持，如果要获得 Spring 官方的支持，只能等待下一次的发布了。基于在 Spring 中对 MyBatis 提供支持的兴趣，MyBatis 社区认为，应该开始召集有兴趣参与其中的贡献者们，将对 Spring 的集成作为 MyBatis 的一个社区子项目。

于是乎，MyBatis自己动手搞了一个Spring的扩展实现，呕吼！牛逼！

众所周知，MyBatis作为一个持久层框架它支持自定义 SQL、存储过程以及高级映射。通过xml映射到接口，使开发者使用接口的方式就能够轻松的映射、解析、执行xml中的sql!

但是，你想没想过一件事，MyBatis和Spring整合之后,里面的接口居然能够被Spring进行管理，然后通过 自动注入等Spring的注入手段进行注入！ 有的同学可能没听明白，翻译过来就是，Spring原本只能够管理一个普通类，但是MyBatis只有一个接口，并没有实现类，Spring是如何进行管理的呢？

## 二、MyBatis如何对Spring进行扩展

### 1. 术语介绍

- `ImportBeanDefinitionRegistrar:`这个类是干嘛的？简单来说，他可以创建一个自定义的`BeanDefinition`然后手动的注册到Spring容器中去。
- `BeanDefinitionRegistryPostProcessor:`他是Spring生命周期中一个重要的环节，阅读过之前文章的同学应该记得，Spring生命周期中，会将Class解析成`BeanDefinition`然后注册在`BeanFactory`中, 然后在执行 `BeanFactoryPostProcessor`之前执行这个类的回调，完整一些特定的功能，比如注册一波自定义的bd等操作！
- `ClassPathBeanDefinitionScanner:`他是Spring内置的一个扫描器，可以扫描底层的class文件，从而最终完成从class文件到 `BeanDefinition`的转换！

### 2.源码解析

使用过SpringBoot的同学都知道，如果想要MyBatis使用Spring的自动配置功能，都需要在启动类上加上一个`@MapperScan`,他也是今天的一个源码的重点！

我们先看一下注解`@MapperScan`究竟做了哪些事情！

```java
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
@Documented
//这个是一个重点，这个注解向Spring中导入了一个 MapperScannerRegistrar 类
// 他是ImportBeanDefinitionRegistrar的子类
@Import(MapperScannerRegistrar.class)
@Repeatable(MapperScans.class)
public @interface MapperScan {
    .....忽略不必要代码.....
    String[] basePackages() default {};
    .....忽略不必要代码.....
}
```

这个注解通过`@Import`向Spring注入了一个`MapperScannerRegistrar`,我们进入到他里面看一下源码！

```java
public class MapperScannerRegistrar implements ImportBeanDefinitionRegistrar, ResourceLoaderAware {

  .....忽略不必要代码.....

  /**
   * Spring回调的时候会回调这个方法
   * @param importingClassMetadata 导入类的原信息
   * @param registry 注册工具
   */
  @Override
  public void registerBeanDefinitions(AnnotationMetadata importingClassMetadata, BeanDefinitionRegistry registry) {
    //获取对应类 MapperScan 注解的全部属性信息
    AnnotationAttributes mapperScanAttrs = AnnotationAttributes .fromMap(importingClassMetadata.getAnnotationAttributes(MapperScan.class.getName()));
    if (mapperScanAttrs != null) {
      //调用具体的实现
      registerBeanDefinitions(importingClassMetadata, mapperScanAttrs, registry, generateBaseBeanName(importingClassMetadata, 0));
    }
  }
  
  /**
   * 注册一个 BeanDefinition  ，这里会构建并且向容器中注册一个bd 也就是一个自定义的扫描器 MapperScannerConfigurer
   * @param annoMeta 被@Importd的类的原信息
   * @param annoAttrs 注解的元信息，内部包含所有的注解属性
   * @param registry Spring提供的注册到容器的工具类
   * @param beanName bean的名称
   */
  void registerBeanDefinitions(AnnotationMetadata annoMeta, AnnotationAttributes annoAttrs,
      BeanDefinitionRegistry registry, String beanName) {
	//构建一个 BeanDefinition 他的实例对象是 MapperScannerConfigurer
    //他实际上是一个BeanDefinitionRegistryPostProcessor对象 未来通过Spring对这个类进行创建和回调
    BeanDefinitionBuilder builder = BeanDefinitionBuilder.genericBeanDefinition(MapperScannerConfigurer.class);
      
	.....忽略不必要代码.....
    //向这个bd里面注入一个 basePackage 属性，未来可以通过属性注入的方式注入到 MapperScannerConfigurer 的属性中
    builder.addPropertyValue("basePackage", StringUtils.collectionToCommaDelimitedString(basePackages));
    registry.registerBeanDefinition(beanName, builder.getBeanDefinition());

  }
	.....忽略不必要代码.....
}
```

这一段代码最终的逻辑简单来说就是构建了一个自定义扫描器`MapperScannerConfigurer`然后注册到Bean工厂中，他也就是前面术语项中说的`BeanDefinitionRegistryPostProcessor`的实现类，Spring声明周期中，会自动回调`postProcessBeanDefinitionRegistry()`方法，进行一系列的操作。我们下一步就是进入到`MapperScannerConfigurer`中看一下他做了哪些操作！

```java
public class MapperScannerConfigurer
    implements BeanDefinitionRegistryPostProcessor, InitializingBean, ApplicationContextAware, BeanNameAware {
  /**
   * 自定义扫描器
   * @param registry 注册到bean工厂的工具类
   */
  @Override
  public void postProcessBeanDefinitionRegistry(BeanDefinitionRegistry registry) {
    if (this.processPropertyPlaceHolders) {
      processPropertyPlaceHolders();
    }
    //构建一个自定义的扫描器 他是  ClassPathBeanDefinitionScanner 的子类
    // 可以扫描项目下的class文件转换成BeanDefinition
    ClassPathMapperScanner scanner = new ClassPathMapperScanner(registry);
    .....忽略不必要代码.....
    //这一步是很重要的，他是注册了一系列的过滤器，使得Spring在扫描到Mapper接口的时候不被过滤掉
    scanner.registerFilters();
    //开始执行扫描程序 传入对应要扫描的包路径
    scanner.scan(StringUtils.tokenizeToStringArray(this.basePackage, ConfigurableApplicationContext.CONFIG_LOCATION_DELIMITERS));
  }
}
```

这一段代码主要是在Spring回调这个方法后，这个方法会构建一个`ClassPathMapperScanner`扫描器，他是前面术语项中说到的`ClassPathBeanDefinitionScanner`的子类实现，然后调用 `ClassPathMapperScanner`的`scan`方法，将扫描到的类转换成对应的`BeanDefinition`注册到容器中，正常来说我们应该关注的是scan方法，但是但是，我们在看scan之前，应该重点的关注一下`registerFilters`方法，我们大可看一下他做了哪些操作！然后再去看scan方法！

```java
/**
 * 配置父扫描程序以搜索正确的界面。它可以搜索所有接口或仅搜索那些
 * 扩展了markerInterface或/和那些用notificationClass注释的标记
 */
public void registerFilters() {
    boolean acceptAllInterfaces = true;

    // 如果指定指定注解标注的Mapper
    if (this.annotationClass != null) {
        addIncludeFilter(new AnnotationTypeFilter(this.annotationClass));
        acceptAllInterfaces = false;
    }

    // 指定接口的Mapper接口
    if (this.markerInterface != null) {
        addIncludeFilter(new AssignableTypeFilter(this.markerInterface) {
            @Override
            protected boolean matchClassName(String className) {
                return false;
            }
        });
        acceptAllInterfaces = false;
    }
	//默认的添加所有的Mapper接口为MyBatis类
    if (acceptAllInterfaces) {
        // 默认包含所有类的过滤器
        addIncludeFilter((metadataReader, metadataReaderFactory) -> true);
    }

    // 排除package-info.java
    addExcludeFilter((metadataReader, metadataReaderFactory) -> {
        String className = metadataReader.getClassMetadata().getClassName();
        return className.endsWith("package-info");
    });
}
```

为什么要先看这个呢？因为对于Spring而言，他对一个`BeanDefinition`有着很严格的校验，当扫描的类不符合预定的一些条件的时候，Spring就会把它丢弃掉，不会管理这个类，我们这个方法就是为了，让Spring在扫描到那些接口的时候，添加一些自定义的过滤器，使Spring能够识别我们预定的这些接口，然后转换成`BeanDefinition`!

自定义的过滤器添加完毕后，我们就进入到scan方法去！

```java
/**
 * 在指定的基本程序包中执行扫描。
 * @param basePackages 包以检查带注释的类
 * @return 注册的bean的数量
 */
public int scan(String... basePackages) {
    //获取现有的总数  bd
    int beanCountAtScanStart = this.registry.getBeanDefinitionCount();
    //开始扫描逻辑
    doScan(basePackages);
	.....忽略不必要代码.....
    //统计本次扫描新增加的BeanDefinition数量  使用总共的数量 - 原本的数量
    return (this.registry.getBeanDefinitionCount() - beanCountAtScanStart);
}
```

这一步没的说，他会统计一下本次新加的一个bd的数量，我们进入到`scan`方法

```java
/**
 * 调用父级搜索，该搜索将搜索并注册所有候选者。然后注册的对象处理以将它们设置为MapperFactoryBeans
 * @param basePackages 要扫描的包路径
 * @return 对应的BeanDefinition的包装类
 */
@Override
public Set<BeanDefinitionHolder> doScan(String... basePackages) {
    //调用父类的扫描逻辑，转换为 BeanDefinitionHolder
    Set<BeanDefinitionHolder> beanDefinitions = super.doScan(basePackages);
    if (beanDefinitions.isEmpty()) {
        .....忽略不必要代码.....
    } else {
        //为这些接口的逻辑设置beanClass
        processBeanDefinitions(beanDefinitions);
    }
    //返回这些设置好的包装类
    return beanDefinitions;
}
```

无可厚非，我们肯定先进入到`super.doScan(basePackages)`方法！

> org.springframework.context.annotation.ClassPathBeanDefinitionScanner#doScan 源码解读

```java
/**
 * 在指定的基本软件包中执行扫描，
 * 返回注册的bean定义。
 * 此方法不会注册注释配置处理器而是将其留给调用方。
 * @param basePackages 包以检查带注释的类
 * @return 为工具注册目的而已注册的一组bean（决不{@code null}）
 */
protected Set<BeanDefinitionHolder> doScan(String... basePackages) {
    .....忽略不必要代码.....
    Set<BeanDefinitionHolder> beanDefinitions = new LinkedHashSet<>();
    for (String basePackage : basePackages) {
        //查找候选组件主要是查找spring的bean  完成扫描的  这个是将传入的包路径下的类（符合条件的） 转换成对应的bd
        Set<BeanDefinition> candidates = findCandidateComponents(basePackage);
        .....忽略不必要代码.....
    }
    //返回本次经过全部流程扫描的bean
    return beanDefinitions;
}
```

这个代码篇幅原因我忽略了不少，具体源码注释如下：

![image-20200824164039305](http://images.huangfusuper.cn/typora/classpathScan扫描逻辑如下08242020.png)

当然，我们最需要关注的就是` findCandidateComponents(basePackage)`方法，他是真正的扫描逻辑，真正的将一个class行对象变为`BeanDefinition`

![image-20200824164352332](http://images.huangfusuper.cn/typora/扫描逻辑08242020.png)

不想复制了，直接截图，理所应当的进入到了`scanCandidateComponents`方法：

```java
/**
	 * 这个就是扫描 过滤 转换 class成bd的地方
	 * @param basePackage 包路径
	 * @return 转换成功的bd
	 */
private Set<BeanDefinition> scanCandidateComponents(String basePackage) {
    Set<BeanDefinition> candidates = new LinkedHashSet<>();
    try {
        //拼装一个扫描的路径
        String packageSearchPath = ResourcePatternResolver.CLASSPATH_ALL_URL_PREFIX +
            resolveBasePackage(basePackage) + '/' + this.resourcePattern;
        //这一步做了递归拿到所有的类，这一步读取了配置类里面配置的路径文件
        //然后通过包名以及io手段将包名替换成文件夹的全路径，通过递归拿到里面所有的类文件
        Resource[] resources = getResourcePatternResolver().getResources(packageSearchPath);
        .....忽略不必要代码.....
            //这里开始将对应的类资源文件转换成对应的bd
            for (Resource resource : resources) {
                .....忽略不必要代码.....
                    if (resource.isReadable()) {
                        try {
                            MetadataReader metadataReader = getMetadataReaderFactory().getMetadataReader(resource);
                            //这一步是扫描判断过滤器的
                            //可以通过 addIncludeFilter 添加一些匹配规则
                            //这个就是我们前面添加到的过滤器，不然的话在这里就不会生效
                            //也不会添加到容器中
                            if (isCandidateComponent(metadataReader)) {
                                //构建一个扫描bean的定义
                                ScannedGenericBeanDefinition sbd = new ScannedGenericBeanDefinition(metadataReader);
                                //设置源
                                sbd.setResource(resource);
                                sbd.setSource(resource);
                                //这一步是判断这个是不是 接口等  可以由子类复写
                                //这个判断也很重要，下面一张图会详细解释
                                if (isCandidateComponent(sbd)) {
                                    if (debugEnabled) {
                                        logger.debug("Identified candidate component class: " + resource);
                                    }
                                    //确定是一个候选组件的话就把这个放到候选组件的集合里面
                                    candidates.add(sbd);
                                }
                                .....忽略不必要代码.....
                            }
                            .....忽略不必要代码.....
                        } 
                        .....忽略不必要代码.....
                    }
                .....忽略不必要代码.....
            }
    }
    catch (IOException ex) {
        throw new BeanDefinitionStoreException("I/O failure during classpath scanning", ex);
    }
    //返回 筛选转换的候选bean
    return candidates;
}
```

上述代码片段中，第二段判断`isCandidateComponent(sbd)`,只有它通过的时候，才会被加载到候选组件中，在Spring原本的逻辑中，他是不会被加载进来的，但是，因为MyBatis重写了这段逻辑，所以，他才会被加载，重写逻辑如下：

![image-20200824165316248](http://images.huangfusuper.cn/typora/MyBatis判断类是否加载进验证逻辑中20200824.png)

至此，我们的接口被扫描出来，并转换成了 `BeanDefinition`,我们逐步返回到最终的调用逻辑`org.mybatis.spring.mapper.ClassPathMapperScanner#doScan`中：

![image-20200824165606490](http://images.huangfusuper.cn/typora/原始调用逻辑20200824.png)

我们将上一步扫描到的 `BeanDefinitionHolder` 使用箭头所指的方法设置了一些属性，什么属性呢？

```java
/**
 * 给扫描到的处理器设置一些自定义的属性
 * @param beanDefinitions 对应接口的 beanDefinition
 */
private void processBeanDefinitions(Set<BeanDefinitionHolder> beanDefinitions) {
    GenericBeanDefinition definition;
    for (BeanDefinitionHolder holder : beanDefinitions) {
      .....忽略不必要代码.....
      // 映射器接口是Bean的原始类但是，bean的实际类是MapperFactoryBean
      //这里传入的是对应接口的全限定名，未来注入到 mapperFactoryBean中后，会被自动的转换成class
      definition.getConstructorArgumentValues().addGenericArgumentValue(beanClassName);
      //设置对应的class，细心点你会发现，他注入的属性并不是对应的接口，而是一个 MapperFactoryBean.class
      definition.setBeanClass(this.mapperFactoryBeanClass);
	  .....忽略不必要代码.....
  }
}
```

这一段逻辑特别重要，为什么呢？因为要知道我们扫描出来的bd都是接口类型的，在java中，接口是不能被实例化的，想要让Spring管理这些Mapper接口，那么Spring所实例化的必须是一个具体的类，所以，这里就注入了一个`MapperFactoryBean `，他是`FactoryBean`类型的对象，Spring后续在实例化这个Mapper接口的时候，会通过`FactoryBean`实例化！我们进入到`MapperFactoryBean `中查看对象！

在看这个之前，我们需要了解`FactoryBean`的最基础的知识，就是Spring在创建对象的时候，如果发现这个对象是一个`FactoryBean`类型的数据，那么会调用`getObject`方法，获取对应的对象，所以，我们只需要关注`org.mybatis.spring.mapper.MapperFactoryBean#getObject`方法，就可以看出Spring究竟是如何把一个接口变为具体的Mapper操作实现类的！

```java
public class MapperFactoryBean<T> extends SqlSessionDaoSupport implements FactoryBean<T> {
  /**
   * 通过注入额 mapperInterface全限定名，自动转换为class对象
   */
  private Class<T> mapperInterface;
    
  .....忽略不必要代码.....

  /**
   * spring会回调这个方法获取最终的对象
   * @return 要创建的对象
   * @throws Exception 异常
   */
  @Override
  public T getObject() throws Exception {
    return getSqlSession().getMapper(this.mapperInterface);
  }

  /**
   * 要创建对象的类型
   * @return 什么类型？
   */
  @Override
  public Class<T> getObjectType() {
    return this.mapperInterface;
  }

  /**
   * 是不是单例
   * @return 是单例吗？
   */
  @Override
  public boolean isSingleton() {
    return true;
  }
  .....忽略不必要代码.....
}
```

由此可见，getObject通过 `getSqlSession`调用MyBatis逻辑，使用jdk动态代理来实现对接口的转换操作的！

你明白了吗？

整个流程比较麻烦，我们用一张图解决下！

![image-20200824173852899](http://images.huangfusuper.cn/typora/MapperScan注解源码解析示例图.png)

