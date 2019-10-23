# springIOC ann版本

>pom.xml

```xml
	<dependencies>
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
    </dependencies>
```
## 一、自定义注解

> 自定义注解

### 1.Autowired注解

```java
package com.luban.annotatethebook.anno;

import java.lang.annotation.*;

/**
 * 自动注入
 */
@Target({ElementType.CONSTRUCTOR, ElementType.METHOD, ElementType.PARAMETER, ElementType.FIELD, ElementType.ANNOTATION_TYPE})
@Documented
@Retention(RetentionPolicy.RUNTIME)
public @interface Autowired {
}

```

### 2.ComponentScan注解

```java
package com.luban.annotatethebook.anno;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface ComponentScan {
    public String value();
}

```

### 3.Repository注解

```java
package com.luban.annotatethebook.anno;

import jdk.nashorn.internal.objects.annotations.Property;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 标注DAO
 */
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface Repository {
    public String value() default "";
}

```

### 4.Service注解

```java
package com.luban.annotatethebook.anno;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 标注Service
 */
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface Service {
    public String value() default "";
}

```

## 二、注解异常

### 1.没有配置类异常实现

```java
package com.luban.exception;

/**
 * 找不到配置注解异常类
 * @author 皇甫
 */
public class CannotFindAnnotationsException extends RuntimeException {
    public CannotFindAnnotationsException(String msg) {
        super(msg);
    }
}

```

### 2.依赖查找异常

```java
package com.luban.exception;

public class LubanSpringException extends RuntimeException {

    public LubanSpringException(String msg){
        super(msg);
    }
}

```

### 3.重复标注beanNane异常实现

```java
package com.luban.exception;

/**
 * @author 皇甫
 */
public class RepeatAnnotationException extends RuntimeException {
    public RepeatAnnotationException(String msg){
        super(msg);
    }
}

```

## 三、创建器（核心）

```java
package com.luban.util;

import com.luban.annotatethebook.anno.Autowired;
import com.luban.annotatethebook.anno.ComponentScan;
import com.luban.annotatethebook.anno.Repository;
import com.luban.annotatethebook.anno.Service;
import com.luban.exception.CannotFindAnnotationsException;
import com.luban.exception.LubanSpringException;
import com.luban.exception.RepeatAnnotationException;

import java.io.File;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 自定义版本的注解扫描
 * @author 皇甫
 */
public class AnnotationConfigApplicationContext {
    /**
     * 有依赖的Map
     */
    Map<String,Object> relyMap = new HashMap<String, Object>();
    /**
     * 没有依赖的Map
     */
    Map<String,Object> noDependenceMap = new HashMap<String, Object>();
    /**
     * 将实例好的对象全部放入Map集合
     */
    Map<String,Object> map = new HashMap<String, Object>();
    private String fullyQualifiedName;
    public AnnotationConfigApplicationContext(Class target) {
        try {
            getTYpePath(target);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void getTYpePath(Class target) throws ClassNotFoundException, InstantiationException, IllegalAccessException {
        if(target.isAnnotationPresent(ComponentScan.class)){
            ComponentScan componentScanValue = (ComponentScan) target.getAnnotation(ComponentScan.class);
            String packagePath = componentScanValue.value();
            fullyQualifiedName = packagePath;
            //将包名转换为路径名称
            String path = packagePath.replaceAll("\\.","/" );
            //获取当前项目根路径
            String rootPackagePath = this.getClass().getResource("/").getPath();
            //类的全路径名
            String targetPackagePath = rootPackagePath+path;
            File file = new File(targetPackagePath);
            //所有class文件的全路径名称
            List<String> list = new ArrayList<String>();
            list = getPaths(file, list);
            //所有class文件的全限定名
            List<String> fullyQualifiedNames = getFullyQualifiedName(list);
            //所有class文件对应的class对象
            List<Class> classArray = getClassArray(fullyQualifiedNames);
            //返回所有添加注解的类对象
            List<Class> yesAnnotation = scanningAnnotations(classArray);
            //剩余的除了没有依赖的bean类对象 Service
            List<Class> yesRelyArray = getNoDependenceMap(yesAnnotation);
            //实例化有依赖的对象
            getRelyMap(yesRelyArray);
            //合并
            mergeMap();
        }else{
            throw new CannotFindAnnotationsException("找不到"+ComponentScan.class+"注解");
        }
    }

    /**
     * 合并两个Map
     */
    private void mergeMap(){
        for (String noDependenceMapKey : noDependenceMap.keySet()) {
            map.put(noDependenceMapKey, noDependenceMap.get(noDependenceMapKey));
        }

        for (String relyMapKey : relyMap.keySet()) {
            map.put(relyMapKey, relyMap.get(relyMapKey));
        }
    }

    /**
     * 实例化有依赖的对象
     * @param yesRelyArray
     * @throws IllegalAccessException
     * @throws InstantiationException
     */
    private void getRelyMap(List<Class> yesRelyArray) throws IllegalAccessException, InstantiationException {
        String relyMapKey = null;
        for (Class clazz : yesRelyArray) {
            //判断注解里面是否有名字例:@Service(userService)
            Repository repository = (Repository) clazz.getAnnotation(Repository.class);
            Service service = (Service) clazz.getAnnotation(Service.class);
            String repositoryValue = "";
            String serviceValue = "";
            if(repository!=null){
                repositoryValue = repository.value();
            }
            if(service!=null){
                serviceValue = service.value();
            }
            if(repositoryValue != ""){
                relyMapKey = repositoryValue;
            }else if(serviceValue!=""){
                relyMapKey = serviceValue;
            }else{
                throw new RepeatAnnotationException("存在重复注解");
            }

            Field[] declaredFields = clazz.getDeclaredFields();
            if(declaredFields.length>0){
                int i = 0;
                Object o = null;
                for (Field declaredField : declaredFields) {
                    //没有加注解的直接跳过
                    if(!declaredField.isAnnotationPresent(Autowired.class)){
                        continue;
                    }
                    String fieldTypeName = declaredField.getType().getName();
                    //循环没有依赖的Map
                    for (String key : noDependenceMap.keySet()) {
                        String typeName = noDependenceMap.get(key).getClass().getInterfaces()[0].getName();
                        if(fieldTypeName!=null && fieldTypeName.equals(typeName)){
                            i++;
                            o = noDependenceMap.get(key);
                        }
                    }
                    if(i>1){
                        throw  new LubanSpringException("需要一个"+fieldTypeName+"类型的依赖，却找到"+i+"个");
                    }else{
                        //注解值为空时默认使用类名
                        if(relyMapKey==null || relyMapKey.equals("")){
                            relyMapKey = clazz.getSimpleName();
                            relyMapKey = lowerFirst(relyMapKey);
                        }
                        Object object = clazz.newInstance();
                        declaredField.setAccessible(true);
                        declaredField.set(object,o);
                        relyMap.put(relyMapKey, object);
                    }
                }
            }
        }
    }

    /**
     * 首字母小写
     * @param oldStr
     * @return
     */
    private String lowerFirst(String oldStr){
        char[]chars = oldStr.toCharArray();
        chars[0] += 32;
        return String.valueOf(chars);
    }
    /**
     * 返回添加注解的Dao或者Service
     * @param classArray
     * @return
     */
    private List<Class> scanningAnnotations(List<Class> classArray){
        List<Class> daoAndServiceClazz = new ArrayList<Class>();
        for (Class clazz : classArray) {
            if(clazz.isAnnotationPresent(Repository.class) || clazz.isAnnotationPresent(Service.class)){
                daoAndServiceClazz.add(clazz);
            }
        }
        return daoAndServiceClazz;
    }

    /**
     * 查找没有依赖的对象 并实例化
     * @param yesAnnotation
     */
    private List<Class> getNoDependenceMap(List<Class> yesAnnotation){
        String noDependenceMapKey = null;
        for (Class aClass : yesAnnotation) {
            Repository repository = (Repository) aClass.getAnnotation(Repository.class);
            Service service = (Service) aClass.getAnnotation(Service.class);
            String repositoryValue = "";
            String serviceValue = "";
            //判断注解里面是否有名字例:@Repository(userDao)
            if(repository!=null){
                repositoryValue = repository.value();
            }
            if(service!=null){
                serviceValue = service.value();
            }

            if(repositoryValue != ""){
                noDependenceMapKey = repositoryValue;
            }else if(serviceValue!=""){
                noDependenceMapKey = serviceValue;
            }else{
                throw new RepeatAnnotationException("存在重复注解");
            }


            boolean isNoRely = true;
            Field[] declaredFields = aClass.getDeclaredFields();
            for (Field declaredField : declaredFields) {
                if(declaredField.isAnnotationPresent(Autowired.class)){
                    isNoRely = false;
                }
            }
            if(isNoRely){
                //此时的映射关系为  {UserDaoImpl=com.luban.annotatethebook.dao.impl.UserDaoImpl@49476842}
                //疑问   如果不同包的Dao都叫UserDaoImpl 根据map key不能重复的理论，有一个Dao将会注册失败
                try {
                    Object target = aClass.newInstance();
                    //注解值为空时默认使用类名
                    if(noDependenceMapKey==null || noDependenceMapKey.equals("")){
                        noDependenceMapKey = aClass.getSimpleName();
                        noDependenceMapKey = lowerFirst(noDependenceMapKey);
                    }
                    noDependenceMap.put(noDependenceMapKey, target);
                    yesAnnotation.remove(aClass);
                } catch (InstantiationException e) {
                    e.printStackTrace();
                } catch (IllegalAccessException e) {
                    e.printStackTrace();
                }
            }
        }
        return yesAnnotation;
    }

    /**
     * 递归查询所有文件的全路径名
     * @param filePath
     * @param paths
     * @return
     */
    private List<String> getPaths(File filePath,List<String> paths){
        File[] files = filePath.listFiles();
        if(files.length == 0){
            return null;
        }
        for (File file : files) {
            if(file.isDirectory()){
                getPaths(file,paths);
            }else{
                paths.add(file.getPath());
            }
        }
        return paths;
    }

    /**
     * 根据全路径名称返回全限定名
     * @param list
     * @return
     */
    private List<String> getFullyQualifiedName(List<String> list){
        List<String> fullyQualifiedNames = new ArrayList<String>();
        for (String name : list) {
            String s = name.replaceAll("\\\\", "\\.");
            String substring = s.substring(s.indexOf(fullyQualifiedName), (s.length() - 6));
            fullyQualifiedNames.add(substring);
        }
        return fullyQualifiedNames;
    }

    /**
     * 根据全限定名  返回对应的class对象
     * @param list
     * @return
     */
    private List<Class> getClassArray(List<String> list){
        List<Class> classes = new ArrayList<Class>();
        for (String fullyQualifiedName : list) {
            try {
                Class clazz = Class.forName(fullyQualifiedName);
                classes.add(clazz);
            } catch (ClassNotFoundException e) {
                e.printStackTrace();
            }
        }
        return classes;
    }

    public Object getBean(String name){
        return map.get(name);
    }
}

```

## 四、测试

### 1.配置类

```java
package com.luban.annotatethebook.conf;

import com.luban.annotatethebook.anno.ComponentScan;

/**
 * @author 皇甫
 */
@ComponentScan("com.luban.annotatethebook")
public class AppConfig {

}

```

### 2.service注解（不写完了，举个例子）

```java
package com.luban.annotatethebook.service;

/**
 * 用户业务类
 * @author 皇甫
 */
public interface UserService {
    /**
     * 查询方法
     * @return
     */
    public String findUser();
}
```

### 3.测试

```java
package com.luban.annotatethebook.test;

import com.luban.annotatethebook.conf.AppConfig;
import com.luban.annotatethebook.service.UserService;
import com.luban.util.AnnotationConfigApplicationContext;

/**
 * @author 皇甫
 */
public class ConfigTest {
    public static void main(String[] args) {
        AnnotationConfigApplicationContext annotationConfigApplicationContext =
                new AnnotationConfigApplicationContext(AppConfig.class);

        UserService userService= (UserService) annotationConfigApplicationContext.getBean("userService");
        String user = userService.findUser();
        System.out.println(user);
    }

}

```

