# rabbitmq发布订阅

## 一、发布订阅模式

还记得我们上一个文章是如何发布消息的吗？

> 回顾一下以前是如何发送消息的：
>
> ```java
> channel.basicPublish("", QUEUE_NAME, null, message.getBytes());
> ```

对的，以前我们发送消息是直接由生产者将消息发送到队列，可是这种方式官方是不推荐的！

**`RabbitMQ消息传递模型中的核心思想是生产者从不将任何消息直接发送到队列。实际上，生产者经常甚至根本不知道是否将消息传递到任何队列。`**

相反，生产者只能将消息发送到*交换机*。交流是一件非常简单的事情。一方面，它接收来自生产者的消息，另一方面，将它们推入队列。交易所必须确切知道如何处理收到的消息。是否应将其附加到特定队列？是否应该将其附加到许多队列中？还是应该丢弃它。规则由*交换类型*定义 。

你可以将交换机想象成一个分发器更好容易理解，**消息生产者你可以理解为皇帝，他所下发的命令都由圣旨传递，皇帝当然不可能亲自去送圣旨，所以这个工作由太监来承担，这里的太监就是交换机，由太监根据圣旨类型送到文武百官手里，这里文武百官也就是消费者。**大概看一下流程图：

![img](../../image/exchanges.png)

> 其中  X 就是交换机
>
> 交换机类型大概有：
>
> - direct：`直连交换机`根据RouteKey转发到队列
>   - 任何发送到Direct Exchange的消息都会被转发到指定RouteKey中指定的队列Queue；
>   - 生产者生产消息的时候需要执行Routing Key路由键；
>   - 队列绑定交换机的时候需要指定Binding Key,只有路由键与绑定键相同的话，才能将消息发送到绑定这个队列的消费者；
>   - 如果vhost中不存在RouteKey中指定的队列名，则该消息会被丢弃；
> - topic:`通配符交换机`,满足Route Key与Binding Key模糊匹配
>   - 任何发送到Topic Exchange的消息都会被转发到所有满足Route Key与Binding Key模糊匹配的队列Queue上；
>   - 生产者发送消息的时候需要指定Route Key，同时绑定Exchange与Queue的时候也需要指定Binding Key；
>   - #” 表示0个或多个关键字，“*”表示匹配一个关键字；
>   - 如果Exchange没有发现能够与RouteKey模糊匹配的队列Queue，则会抛弃此消息；
>   - 如果Binding中的Routing key *，#都没有，则路由键跟绑定键相等的时候才转发消息，类似Direct Exchange；如果Binding中的Routing key为#或者#.#，则全部转发，类似Fanout Exchange；
> - fanout:`广播式交换机`,所有发送到Fanout Exchange交换机上的消息，都会被发送到绑定到该交换机上面的所有队列上，这样绑定到这些队列的消费者就可以接收到该消息。
>
> header模式在实际使用中较少，本文只对前三种模式进行比较。
>
> 性能排序：fanout >> direct >> topic。比例大约为11：10：6

我们本章专题会着重介绍`fanout  `类型的交换机！

***生产者指定通道交换机类型***

> ```java
> channel.exchangeDeclare(EXCHANGE_NAME,"fanout");
> ```

***生产者不需要创建队列，只需要创建交换机，并且指明该生产者对应的交换机即可，队列的创建由消费者创建，所以发送消息的时候***

> ```java
> channel.basicPublish(EXCHANGE_NAME,"",null,msg.getBytes());
> ```

***消费者需要创建队列，并且绑定到交换机***

> ```java
> //声明队列
> channel.queueDeclare(QUEUE_NAME,false,false,false,null);
> //绑定给交换机
> channel.queueBind(QUEUE_NAME,EXCHANGE_NAME,"");
> ```

***完整代码***

**生产者代码**

```java
package com.ps;

import com.rabbitmq.client.Channel;
import com.rabbitmq.client.Connection;
import com.util.MqConnection;

import java.io.IOException;
import java.util.concurrent.TimeoutException;

/**
 * @author huangfu
 * 队列 消息生产者
 * 发布 订阅模式
 */
public class PSProducer {
    private static String EXCHANGE_NAME = "ps";
    public static void main(String[] args) throws IOException, TimeoutException, InterruptedException {
        Connection connection = MqConnection.getConnection();

        Channel channel = connection.createChannel();
        /**
         *  声明交换机
         *  fanout 不处理路由，分发给所有队列
         *  direct 处理路由 发送的时候需要发sing一个路由key
         */

        channel.exchangeDeclare(EXCHANGE_NAME,"fanout");


        String msg = "醉卧沙场君莫笑";
        /**
         * 第二各参数
         *      匿名转发，路由key
         */
        channel.basicPublish(EXCHANGE_NAME,"",null,msg.getBytes());
        channel.close();
        connection.close();
    }
}

```

**消费者1**

```java
package com.ps;

import com.rabbitmq.client.*;
import com.util.MqConnection;

import java.io.IOException;
import java.util.concurrent.TimeoutException;

/**
 * @author Administrator
 */
public class PsCoummer {
    private static final String QUEUE_NAME = "ps";
    private static final String EXCHANGE_NAME = "ps";
    public static void main(String[] args) throws IOException, TimeoutException {
        //获取连接
        Connection connection = MqConnection.getConnection();
        //创建频道
        final Channel channel = connection.createChannel();
        //声明队列
        channel.queueDeclare(QUEUE_NAME,false,false,false,null);
        /**
         * 告诉消费者每次只发一个给消费者
         * 必须消费者发送确认消息之后我才会发送下一条
         */
        channel.basicQos(1);
        //绑定给交换机
        channel.queueBind(QUEUE_NAME,EXCHANGE_NAME,"");

        //定义一个消费者
        Consumer consumer = new DefaultConsumer(channel){
            @Override
            public void handleDelivery(String consumerTag, Envelope envelope, AMQP.BasicProperties properties, byte[] body) throws IOException {
                System.out.println(new String(body,"UTF-8"));
                try {
                    Thread.sleep(2000);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }finally {
                    System.out.println("[1] done");
                    //发送回执
                    channel.basicAck(envelope.getDeliveryTag(),false);
                }
            }
        };
        /**
         * 第二个参数
         *      true:自动确认
         *          一旦mq将消息分发给消费者  就会从内存中删除，会出现消息丢失
         *      false:手动确认（默认）
         *          如果消费者挂掉，我将此消息发送给其他消费者
         *          支持消息应答，当消费者处理完成后发送给生产者回执，删除消息
         *
         *
         *      当消息队列宕了  内存里的数据依旧会丢失，此时需要将数据持久化
         */
        channel.basicConsume(QUEUE_NAME,false,consumer);
    }
}

```

**消费者2**

```java
package com.ps;

import com.rabbitmq.client.*;
import com.util.MqConnection;

import java.io.IOException;
import java.util.concurrent.TimeoutException;

/**
 * @author Administrator
 */
public class PsCoummer2 {
    private static final String QUEUE_NAME = "ps2";
    private static final String EXCHANGE_NAME = "ps";
    public static void main(String[] args) throws IOException, TimeoutException {
        //获取连接
        Connection connection = MqConnection.getConnection();
        //创建频道
        final Channel channel = connection.createChannel();
        //声明队列
        channel.queueDeclare(QUEUE_NAME,false,false,false,null);
        /**
         * 告诉消费者每次只发一个给消费者
         * 必须消费者发送确认消息之后我才会发送下一条
         */
        channel.basicQos(1);
        //绑定给交换机
        channel.queueBind(QUEUE_NAME,EXCHANGE_NAME,"");

        //定义一个消费者
        Consumer consumer = new DefaultConsumer(channel){
            @Override
            public void handleDelivery(String consumerTag, Envelope envelope, AMQP.BasicProperties properties, byte[] body) throws IOException {
                System.out.println(new String(body,"UTF-8"));
                try {
                    Thread.sleep(2000);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }finally {
                    System.out.println("[2] done");
                    //发送回执
                    channel.basicAck(envelope.getDeliveryTag(),false);
                }
            }
        };
        /**
         * 第二个参数
         *      true:自动确认
         *          一旦mq将消息分发给消费者  就会从内存中删除，会出现消息丢失
         *      false:手动确认（默认）
         *          如果消费者挂掉，我将此消息发送给其他消费者
         *          支持消息应答，当消费者处理完成后发送给生产者回执，删除消息
         *
         *
         *      当消息队列宕了  内存里的数据依旧会丢失，此时需要将数据持久化
         */
        channel.basicConsume(QUEUE_NAME,false,consumer);
    }
}

```

***完成流程图***

![img](../../image/python-three-overall.png)

## 二、临时队列

我们创建队列的方式一般是这样：**`channel.queueDeclare(QUEUE_NAME,true,false,false,null);`**,但是当我们不对全部的消息都感兴趣，而只对一部分消息感兴趣的情况下，获取你应该了解一个概念：***临时队列***

**为了实现这个概念，我们应该去了解两件事来实现这个临时队列**

1. 无论还说呢么时候我们连接队列的时候都需要一个新的队列！所以我们应该创建一个有随机名称的队列！
2. 一旦断开连接，队列将自动删除！

当然，rabbitmq的客户端已经为我们实现这个，纳闷创建一个临时队列应该怎么来做呢？

> ```java
> String queueName = channel.queueDeclare().getQueue();
> ```
>
> - 这么创建，他会创建一个临时队列，并且返回队列的名字！
> - 在Java客户端中，当我们不向queueDeclare（）提供任何参数时，我们将 使用生成的名称创建一个非持久的，排他的，自动删除的队列

