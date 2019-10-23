>  今日，闲来无事，根据自己的理解手写一版SpringIOC的注入流程，尽管是简化版本的，但是依旧能够帮助我们很好的理解SpringIOC为什么能够做到自动注入，他的底层实现，又究竟做了哪些操作呢？下面让我们一起进行探索吧！


### 一.项目中可能会使用到的jar资源 本想木采用maven 的形式，因为要解析xml所以我这里的技术选型是 dom4j 有其他想法的小伙伴可以自己选择！
>1.pom文件
```xml
        <dependency>
            <groupId>dom4j</groupId>
            <artifactId>dom4j</artifactId>
            <version>1.6.1</version>
        </dependency>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.12</version>
       </dependency>
```
>2.自定义异常
```java
public class LubanSpringException extends RuntimeException {

    public LubanSpringException(String msg){
        super(msg);
    }
}
```
>3.SpringIOC的手动注入流程
```java
import com.luban.exception.LubanSpringException;
import org.dom4j.Attribute;
import org.dom4j.Document;
import org.dom4j.Element;
import org.dom4j.io.SAXReader;

import java.io.File;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

/**
 * @author 皇甫
 */
public class SpringBeanFactory {
    /**
     * 定义一个HashMap映射，映射beanName和对应类的关系
     */
    private Map<String,Object> map = new HashMap<String, Object>();
    public void springBeanFactory(String xml){
        xmlAnalysis(xml);
    }

    /**
     * 解析XML
     * @param xml
     */
    private void xmlAnalysis(String xml){
        //读取配置文件
        File file = new File(this.getClass().getResource("/").getPath()+"/"+xml);
        SAXReader reader = new SAXReader();
        try {
            Document document = reader.read(file);
            Element rootElement = document.getRootElement();
            //判断是否有自动注入的配置
            Attribute attribute = rootElement.attribute("default-autowire");
            boolean flag = false;
            if(attribute != null){
                flag = true;
            }
            for (Iterator<Element> it = rootElement.elementIterator(); it.hasNext();) {
                Element element = it.next();
                // do something
                Attribute attributeId = element.attribute("id");
                String beanId = attributeId.getValue();
                Attribute attributeClassName = element.attribute("class");
                String beanClassName = attributeClassName.getValue();
                Class clazz = Class.forName(beanClassName);
                /**
                 * 维护依赖关系
                 * 遍历子集标签 手动设置注入
                 */
                Object object = null;
                //遍历子集 bean
                for (Iterator<Element> childIt = element.elementIterator(); childIt.hasNext();) {
                    Element childElement = childIt.next();
                    // do something
                    //如果为set注入
                    if(childElement.getName().equals("property")){
                        //获取当前对象的类对象
                        object = clazz.newInstance();
                        //获取当前类所依赖的类的BeanName
                        String childElementRefValue = childElement.attribute("ref").getValue();
                        //根据需要的BeanName去Map映射中寻找对应的对象
                        Object o = map.get(childElementRefValue);
                        String nameValue = childElement.attribute("name").getValue();
                        //根据注入的名字获取属性名
                        Field field = clazz.getDeclaredField(nameValue);
                        field.setAccessible(true);
                        //设置属性的值
                        field.set(object, o);
                    //如果为构造方法注入
                    }else if(childElement.getName().equals("constructor-arg")){
                        //获取要注入的对象的id
                        String refValue = childElement.attribute("ref").getValue();
                        //取出Map
                        Object o = map.get(refValue);
                        //向构造方法中注入文件
                        Constructor constructor = clazz.getConstructor(o.getClass().getInterfaces()[0]);
                        object = constructor.newInstance(o);
                    }else{

                    }
                }

                //如果设置了自动注入
                if(flag){
                    //如果为根据类型注入
                    if(attribute.getValue().equals("byType")){
                        //判断此类是否有依赖 和获取全部的属性
                        Field[] fields = clazz.getDeclaredFields();
                        for (Field field : fields) {
                            //获取对象的类型
                            Class fieldType = field.getType();
                            int count = 0;
                            Object injectObject = null;
                            for (String s : map.keySet()) {
                                if(map.get(s).getClass().getInterfaces()[0].getName().equals(fieldType.getName())){
                                    count++;
                                    injectObject = map.get(s);
                                }
                            }
                            //如果对象类型匹配个数大于1证明由两个类型，需要抛出异常
                            if(count>1){
                                throw new LubanSpringException("只需要一个类型，却找到了两个类型");
                            }else{
                                object = clazz.newInstance();
                                Field[] fs = clazz.getDeclaredFields();
                                field.setAccessible(true);
                                field.set(object, injectObject);
                            }
                        }
                    //如果设置为根据名字注入
                    }else if(attribute.getValue().equals("byName")){
                        //判断此类是否有依赖
                        Field[] fields = clazz.getDeclaredFields();
                        for (Field field : fields) {
                            Class fieldType = field.getType();
                            for (String s : map.keySet()) {
                                if (map.get(s).getClass().getInterfaces()[0].getSimpleName().equals(fieldType.getSimpleName())) {
                                    object = clazz.newInstance();
                                    field.setAccessible(true);
                                    field.set(object, map.get(s));
                                }
                            }
                        }
                    }

                }

                //如果没有依赖，创建对象
                if(object==null){
                    object = clazz.newInstance();
                }
                map.put(beanId, object);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public Object getBean(String beanName){
        return map.get(beanName);
    }
}
```

### 二.测试
>1.定义DAO
```java
/**
 * @author 皇甫
 */
public interface UserDao {
    /**
     * 查询数据路
     */
    public void find();
}
```
>2.定义DAO实现类
```java
import com.luban.dao.UserDao;

public class UserDaoImpl implements UserDao {
    public void find() {
        System.out.println("查询数据库");
    }
}
```
>3.定义Service接口
```java
/**
 * @author 皇甫
 */
public interface UserService {
    /**
     * 查询
     */
    public void find();
}
```
>4.定义Service实现类
```java
import com.luban.dao.UserDao;
import com.luban.service.UserService;

/**
 * @author 皇甫
 */
public class UserServiceImpl implements UserService {
    private UserDao userDao;

    public void find() {
        userDao.find();
    }
}
```
>5.定义xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans default-autowire = "byName">
    <bean id="dao" class="com.luban.dao.impl.UserDaoImpl"></bean>
    <bean id="dao1" class="com.luban.dao.impl.UserDaoImpl"></bean>
    <bean id="service" class="com.luban.service.impl.UserServiceImpl"></bean>
</beans>
```

>6.测试
```java
import com.luban.service.UserService;
import com.luban.util.SpringBeanFactory;
import org.junit.Test;

/**
 * @author 皇甫
 */
public class TestSpringIoc {
    @Test
    public void test1(){
        SpringBeanFactory springBeanFactory = new SpringBeanFactory();

        springBeanFactory.springBeanFactory("spring.xml");
        UserService service = (UserService) springBeanFactory.getBean("service");
        service.find();
    }
}
```