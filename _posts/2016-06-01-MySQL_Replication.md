---
layout: page
title:  "MySQL Replication－理论基础"
date:   2016-5-31 21:52:07
categories: DBMS
tags: DBMS
---
前言：很多公司在最开始的时候，网络架构模型一般都是一个LAMP就够用了，之后业务规模越来越大，就会遇到扩展这个问题。

一般有两个选择：

- scale up  向上扩展，垂直扩展

scale up是针对服务器进行硬件上的提升，这是一个非常不理想的扩展方式

> - 硬件水平提升代价太大
> - 性能只能提升到某个程度

![](https://chenyanshan.github.io/img/linux/server/MySQL_Replieation/1-scale%20up.png?raw=true)

- scale out 向外扩展，水平扩展

scale out这种扩展方式是增加服务器，架设集群

> - 花费的代价小
> - 性能提升大
> - 如果之前是单服务器，现在组成集群还可以实现业务的高可用

标准的说：用廉价的X86组成高性能，高可用集群

MySQL Replication一般分为：

- 一主一从 Master to Slave

![](https://chenyanshan.github.io/img/linux/server/MySQL_Replieation/2-master_to_slave.png?raw=true)

- 一主多从 Master to Multiple Slaves

![](https://chenyanshan.github.io/img/linux/server/MySQL_Replieation/3-master_to_multiple_slaves.png?raw=true)

- 双主模型 Multi—Master

![](https://chenyanshan.github.io/img/linux/server/MySQL_Replieation/4-multi_master.png?raw=true)

- 多级复制 Master to Slave(s) to Slave(s)

![](https://chenyanshan.github.io/img/linux/server/MySQL_Replieation/5-master_to_slaves_to_slavers.png?raw=true)

- 环状模型 Multi—Master Ring

![](https://chenyanshan.github.io/img/linux/server/MySQL_Replieation/6-multi-master_ring.png?raw=true)

图中箭头指向表示数据复制方向
都是Slave复制Master的数据，然后再向外提供查询请求

MySQL Replication的工作模式

> 同步：

- 写入的时候主服务器将二进制日志存储下来之后，并发送给从服务器，获得从服务器接收到二进制日志并将二进制日志重放写入了数据文件的应答之后，主服务器再给client响应，如果不在一个机房，一般就会极大的降低性能。

> 异步(默认异步)：

- 主服务器自己将修改操作写入到数据文件和二进制日志文件中就给client响应。不关心是否有从服务器，这样一来数据绝对可靠不能保证，当数据量过大的时候，从服务器一般都会慢主服务器一点点，主服务器一旦宕机，从服务器或多或少会丢失一些数据。


MySQL的主从同步是依靠MySQL的复制功能。

复制原理：

![](https://chenyanshan.github.io/img/linux/server/MySQL_Replieation/7_replication.png?raw=true)

MySQL除了数据文件还会有其他的日志文件，比如说事务日志，慢查询日志。

Bingary log(二进制日志)也是其中一种，二进制日志是将对数据库进行的DML(select除外)、DDL操作都会记录到其中，说明白点就是当前服务器的数据修改和有潜在可能性影响数据修改的语句都会被记录其中，而且这个文件可以被修改和重放(将里面的纪录重新运行一遍)，这样一来。二进制日志的作用就大了。一般来说，增量备份和复制都需要用到二进制日志

Relay log(中继日志)其实就是Slave将Master的Bingary log日志复制过来。然后在Slave中存下来，就叫做中继日志。

有了上面的基础。就可以讲一下上面那张图了

- 1，mysqld进程在将对数据修改的操作写入磁盘的同时，还写入了Bingary log一份，当然Bingary log功能需要手动开启
- 2，Dump：binlogdump，负责将Slave I/O thread请求的资源发送给对方，所以Dump叫二进制转储线程，也叫做倾倒线程
- 3，I/O thread，负责从Master取回Bingary log存储到Relay log中。I/O      thread并不是轮询状态，为了节省资源，I/O thread是由Master唤醒的。
- 4，SQL thread，它读取Relay log的内容，并重放。

这个图只是对应最简单的主从同步，当然，多级复制也差不多这样，只是Slave也开启了Bingary log功能。
实现的话，下一篇将详细介绍
