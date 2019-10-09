# rabbitmq主题订阅

## 一、topic 模式交换机

上一篇文章讲述了关于直接连接交换机根据key找到对应队列的方式，实现特殊消息特殊队列消费的目的，但是事实上，生产环境下，对于消息的复杂性远不是这样就能够解决的！比如：你要监控有个用户的操作行为，用户的操作行为太多了 增删改查，如果一个一个的写难免会有遗漏，这个时候，我们可以用**通配符**  user.* 轻松解决！这就是mq的**主题模式**！



***这里的交换机类型为 topic 模式的，他更像direct模式，只不过direct是单个匹配，而topic是通配符匹配***

> - `*`:代表一个字符
> - `#`:代表多个字符

**他的用法极其类似于direct 模式，我们不多说了，直接看代码**

## 二、主要代码

`消息生产者`:**消息生产者,在发送消息的时候需要指定消息类型**

```java
String msg = "醉卧沙场君莫笑";
//关注第二个参数
channel.basicPublish(EXCHANGE_NAME,"huangfu.del",null,msg.getBytes());
```

`消息消费者`：**消息消费者，在绑定交换机的时候需要指定通配符**

```java
//绑定交换机
channel.queueBind(QUEUE_NAME,EXCHANGE_NAME,"huangfu.#");
```

## 三、详细代码

**`消息生产者`**

```java
package com.topics;

import com.rabbitmq.client.Channel;
import com.rabbitmq.client.Connection;
import com.util.MqConnection;

import java.io.IOException;
import java.util.concurrent.TimeoutException;

/**
 * 发布订阅模式
 * 主题模式
 * @author huangfu
 */
public class TopicsSend {
    private static String EXCHANGE_NAME = "topic";
    public static void main(String[] args) throws IOException, TimeoutException {

        Connection connection = MqConnection.getConnection();
        Channel channel = connection.createChannel();

        channel.exchangeDeclare(EXCHANGE_NAME,"topic");

        String msg = "醉卧沙场君莫笑";
        channel.basicPublish(EXCHANGE_NAME,"huangfu.del",null,msg.getBytes());
        System.out.println("send:"+msg);
        channel.close();
        connection.close();
    }
}
```

**`消费者1`**

```java
package com.topics;

import com.rabbitmq.client.*;
import com.util.MqConnection;

import java.io.IOException;
import java.util.concurrent.TimeoutException;

/**
 * @author Administrator
 */
public class TopicsRecv {
    private static String QUEUE_NAME = "topics";
    private static String EXCHANGE_NAME = "topic";
    public static void main(String[] args) throws IOException, TimeoutException {
        Connection connection = MqConnection.getConnection();
        final Channel channel = connection.createChannel();

        //声明对垒
        channel.queueDeclare(QUEUE_NAME,false,false,false,null);

        //绑定交换机
        channel.queueBind(QUEUE_NAME,EXCHANGE_NAME,"huangfu.add");

        channel.basicQos(1);

        Consumer consumer = new DefaultConsumer(channel){
            @Override
            public void handleDelivery(String consumerTag, Envelope envelope, AMQP.BasicProperties properties, byte[] body) throws IOException {
                System.out.println(new String(body,"UTF-8"));
                channel.basicAck(envelope.getDeliveryTag(),false);
            }
        };

        channel.basicConsume(QUEUE_NAME,false,consumer);
    }
}

```

**`消费者2`**

```java
package com.topics;

import com.rabbitmq.client.*;
import com.util.MqConnection;

import java.io.IOException;
import java.util.concurrent.TimeoutException;

/**
 * @author Administrator
 */
public class TopicsRecv2 {
    private static String QUEUE_NAME = "topics2";
    private static String EXCHANGE_NAME = "topic";
    public static void main(String[] args) throws IOException, TimeoutException {
        Connection connection = MqConnection.getConnection();
        final Channel channel = connection.createChannel();

        //声明对垒
        channel.queueDeclare(QUEUE_NAME,false,false,false,null);

        //绑定交换机
        channel.queueBind(QUEUE_NAME,EXCHANGE_NAME,"huangfu.#");

        channel.basicQos(1);

        Consumer consumer = new DefaultConsumer(channel){
            @Override
            public void handleDelivery(String consumerTag, Envelope envelope, AMQP.BasicProperties properties, byte[] body) throws IOException {
                System.out.println(new String(body,"UTF-8"));
                channel.basicAck(envelope.getDeliveryTag(),false);
            }
        };

        channel.basicConsume(QUEUE_NAME,false,consumer);
    }
}

```

