# MyBatis为了解决二级缓存脏读问题，究竟做了那些骚操作！
## 一、存在即合理

MyBatis为了提高我们的查询性能，专门设计了一级缓存和二级缓存，众所周知，我们在开发环境中，使用的缓存的时候，也会遇到各种各样的挑战，比如`缓存穿透`，`缓存雪崩`，`数据脏读`等等各种各样的问题，MyBatis也同样，在设计二级缓存的时候，MyBatis也同样遇见了各种挑战；

我这几天在观看MyBatis对于二级缓存的设计的时候，突然发现，我们查询出来一个数据后并没有直接放置到二级缓存中，而是放到了另外一个存储空间，只有提交了之后才会被设置进二级缓存，我不仅疑惑，存在即合理，为什么MyBatis在设计二级缓存的时候，要“多此一举”呢？所以也就有了作者熬夜深入探究的过程！

![](http://images.huangfusuper.cn/typora/开始你的演讲710.jpg)

## 二、测试代码

首先为了方便测试，我们先搞个能够命中二级缓存的实例代码：

```java
@Test
public void sessionTest(){
    SqlSession sqlSession = sqlSessionFactory.openSession(ExecutorType.REUSE, true);
    List<Object> objects = sqlSession.selectList("com.huangfu.TestMapper.selectUser","周六");
    List<Object> objects1 = sqlSession.selectList("com.huangfu.TestMapper.selectUser","周六");
    //哦吼  提交一哈
    sqlSession.commit();
    List<Object> objects2 = sqlSession.selectList("com.huangfu.TestMapper.selectUser","周六");
}
```

注：上面已经说到了，只有在提交之后才会将缓存刷新到二级缓存空间，原理后面会探究，此处属于作者嘚吧嘚！

这里会命中几次呢？你是不是猜的两次？如果你猜的两次，那么你肯定是不了解暂存区的概念，事实上，在第一次查询后，查询的结果并不会同步到二级缓存空间，只有在提交后，才会刷新进去，所以正确答案是`只命中一次，命中率是 0.3333333333333333`

至于这个原因嘛，听作者细细道来：

## 三、探究真理

首先大家要了解一个概念：`暂存区`，他是保存SqlSession在事务中需要向某个二级缓存提交的缓存数据，因为事务过程中的数据可能会回滚，所以不能直接把数据就提交二级缓存，而是暂存在TransactionalCache中，在事务提交后再将过程中存放在其中的数据提交到二级缓存，如果事务回滚，则将数据清除掉！

可以把暂存区理解为一个中间容器，它是为了保证一个事务原子性的容器，它存储这一个提交操作前的全部数据，待提交操作执行后，再将暂存区的内容一次性刷新到二级缓存空间内！

前几篇关于MyBatis的文章我说到过，有关二级缓存的逻辑被抽象到了`CachingExecutor`内部，既然我们开启了二级缓存，按照`会话对象：执行器 = 1：1`的说法，那么咱们示例代码的的执行器一定是`CachingExecutor`,看过我前面文章的人大概应该知道，查询方法会默认执行`query`方法，那么我们重点 debug的对象，应该是 `query`方法。

```java
  @Override
  public <E> List<E> query(MappedStatement ms, Object parameterObject, RowBounds rowBounds, 
              ResultHandler resultHandler, CacheKey key, BoundSql boundSql) throws SQLException {
    //获取该命名空间下的的二级缓存空间
    Cache cache = ms.getCache();
    if (cache != null) {
      //是否设置了刷新暂存区
      flushCacheIfRequired(ms);
      if (ms.isUseCache() && resultHandler == null) {
        ensureNoOutParams(ms, boundSql);
        @SuppressWarnings("unchecked")
        //查询二级缓存空间里面的缓存数据
        List<E> list = (List<E>) tcm.getObject(cache, key);
        //如果二级缓存空间没有查到数据
        if (list == null) {
          //查询数据库
          list = delegate.query(ms, parameterObject, rowBounds, resultHandler, key, boundSql);
          //将查询数据放置到暂存区
          tcm.putObject(cache, key, list);
        }
        return list;
      }
    }
    return delegate.query(ms, parameterObject, rowBounds, resultHandler, key, boundSql);
  }
```

可以看到，事实上，我们的插叙出来的数据并没有被放置到缓存区，而是被放置在了暂存区，至于原因，我们下面再谈！那么什么时候会从暂存区刷新到缓存区呢？是提交时的操作，我们看一下`commit`的基本逻辑！

一路源码追踪，会看到如下的逻辑

```java
private void flushPendingEntries() {
    //遍历所有的暂存区数据，一个一个的放置到二级缓存空间
    for (Map.Entry<Object, Object> entry : entriesToAddOnCommit.entrySet()) {
      delegate.putObject(entry.getKey(), entry.getValue());
    }
    ..... 忽略讨论之外的代码....
  }
```

此时不仅恍然大悟，原来命中一次的原因是这样，只有提交了之后，才会被刷新进二级缓存区，所以提交后的查询才被命中缓存，那么话又说回来，用意何在？

其实仅仅是为了避免脏数据，试想一下，如果没有暂存区空间会有什么情况发生？

假设发生了一个写操作，执行完成后另外一个请求查询到了该数据直接放置到二级缓存区域，但是此时这条数据执行了回滚操作，那么此时就会造成一个脏读！

![image-20200710135312612](http://images.huangfusuper.cn/typora/脏读710.png)

基于上图反之，我们在进行修改操作的时候，依旧不能够直接清空二级缓存空间，而是伪清除（留存一个清除标记），待提交操作的时候，才真正的执行删除操作！

所以在修改方法里面有这样一段代码：

```java
public void clear(Cache cache) {
    //clear方法调用如下
  getTransactionalCache(cache).clear();
}

public void clear() {
    //设置清除标记
    clearOnCommit = true;
    entriesToAddOnCommit.clear();
  }
```

可以看到，修改方法事实上并不会去去清空二级缓存区域，而是设置了一个提交标识，那么这个提交标识有什么用处呢？

```java
public void commit() {
    //当设置清除标记的时候删除二级缓存
    if (clearOnCommit) {
        delegate.clear();
    }
    //刷新暂存区到缓存区
    flushPendingEntries();
    //恢复个数值位置 比如 提交标记重置为false
    reset();
}
```

为啥又要多次一步？

一个修改操作，修改完数据后，将二级缓存清空，但是此时数据异常，发生回滚！事实上，数据没有修改成功，我们是不应该去清空二级缓存的，这是不应该的！所以在没有提交前，是不能清空缓存区的！

经过以上的分析，我们总结出大概流程如下：

![<u></u>](http://images.huangfusuper.cn/typora/7100100000.png)

一个暂存区，就能够避免部分数据脏读问题，不得不感叹MyBatis设计的精妙之处！但是这真的能够解决脏读问题吗？事实上并不是如此！下面扩展一些因为一些特殊原因引起的脏读问题！

![](http://images.huangfusuper.cn/typora/夸我710.jpg)

## 四、扩展知识

因为MyBatis数据二级缓存的设计对于不同的命名空间是隔离的（一个Mapper 用一个二级缓存），所以，在特定情况下依旧会出现脏读的数据！

![<u></u>](http://images.huangfusuper.cn/typora/12312321312.png)

这个出现的原因是因为不同的Mapper查询隔离分别使用不同的存储空间，那么当两个Mapper操作同一张表时就出现脏读的问题，如何解决呢？

想一下，出现这个问题的原因是什么？是因为没有公用一个缓存区，那么我们使用同一个缓存区就能够解决了吧！如何使用呢？

```xml
只需要在对应的Mapper文件中，将该Mapper的命名空间引用另外一个Mapper的命名空间就可以使两个Mapper共用一个缓存空间！
<cache-ref namespace="xxx.xxx.xxx.UserMapper2"></cache-ref>
```

当然还有其他的解决方案，比如注解级别的，作者就不一一赘述了！其实，这两天我看网上的一些资料，作者应该是第一个专门介绍暂存区的人，如果文章中有理解有问题，欢迎各位指正！

