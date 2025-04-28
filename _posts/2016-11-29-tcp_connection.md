---
layout: page
title:  "站在运维的角度理解 TCP connect 和 TCP 状态"
date:   2016-11-29 00:52:07
categories: Network
tags: Network
---

准备写一个 Linux网络调优，忽然想到很多运维对TCP/IP协议不是很了解，网上的文章也基本不是站在运维的角度来讲述，而且很多有关TCP/IP三次握手，四次断开的文章都是错的(你没有看错，很多写的似很厉害的文章，都是错的)，所以还是准备自己写一篇，也加深自己的理解。

注： 本文所有的`Client`和`Server`都是广义的，狭义的表示应该是一个套接字，也就是 `ip:port`


## 一、TCP 三次握手

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/DraggedImage.png?raw=true)

第一步：
> `Client` 会向 `Server` 发送一个有 `SYN` 标志位的TCP包，表示自己要建立TCP连接。

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/WechatIMG5.jpeg?raw=true)

第二步： 
> `Server` 就会返回一个 `SYN+ACK` 包， `ACK` 是确认之前 `Client` 发送过来的 `SYN` 包， `SYN` 表示自己也准备好建立连接了。

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/WechatIMG5-1.jpeg?raw=true)

第三步：
> `Client` 会向 `Server` 发送一个有 `ACK` 标志位的 TCP报文，表示自己确认 `Server` 发送过来的带 `SYN` 标志位TCP连接请求

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/WechatIMG6.jpeg?raw=true)

在这里要仔细说明一下。`Acknowledgment number (确认序列号)` 不是 `ACK(Acknowledgment)`,这就是我一开始说的，很多人错的地方。上面我特意把`Acknowledgment number` 和 `Sequence number` 没有抹掉的原因。`Acknowledgment number` 和 `Sequence number` 就是序列号和确认序列号，用来确认序列的。而所谓的`SYN`、`ACK`。其实就是一个标志位。也就是下面图中的 `TCP Flags`，实际上就是六位二进制表示的。标志位所在位为0就是`Not set`，标志位所在位为1就是`Set`，从上面`Wireshark`抓的包也可以看出来。`0x012`不就是`001010`,对应下图不就是`ACK + SYN`吗。

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/tcp_header.png?raw=true)

(注: 上图我是从 `images.Google.com` 随便找的, 如有侵权请联系 `yanshanchen@hotmail.com`, 立即更换....)

标志位解释(只解释对我们最有用的，相信太多人字多不看...)


- 同步标志位SYN：在建立连接是用来同步序号。`SYN`表示一个连接请求报文段。
- 确认标志位ACK：ACK表示这是一个确认的TCP包
- 终止标志位FIN：表明此报文段的发送端的数据已经发送完毕，并要求释放传输连接。在后面会出现

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/DraggedImage-1.png?raw=true)


各状态解释：

- `CLOSED`: 表示端口未被启用。
- `LISTEN`: `Server` 先启动 `Service`， `Server` 就会进入 `LISTEN` 模式。相信大家已经看到过太多的 `bind-address`, `Listen` 配置了。这个就是监听状态。
- `SYN_RCVD`: 和 `SYN_SEND` 一个发送，一个接收，还加上了 `SYN` 的关键词，相信一下就可以记得住，而且这个状态基本看不到。 
- `SYN_SEND`: 这个是`Clinet`独有状态，当然 `Zabbix_server` 向 `Zabbix_Agent`取数据的时候也会进入这个状态。到底怎么来的呢？可能有编程经验的童鞋容易理解。当`Client`打开连接`Server`的`Socket`的时候就会发送带`SYN`标志位的 TCP报文。然后就进入了这个状态，如果不理解就不需要理解了。就是`Clinet`发送了一个`SYN` TCP 报文 给 `Server` 之后就进入了这个状态。
 - `ESTABLISHED`: 已连接，这个时候就应该是 `Client GET POST` 的时候了。

## 二、TCP connection `四次断开`

四次断开有两种情况，一种是 `Client`先断开，一种是`Server`先断开。为什么会出现这两种情况，后面会详细讲述，而且会进行测试，我们先讲述一下在标志位上面的通信

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/DraggedImage-2.png?raw=true)

为了表达清楚意思，所以我就不使用 `Server` 和 `Client`，而上图所表示的也没有`Client`和`Server`，因为谁都可以先断开

第一步：
> `先断开端` 向 `后断开端` 发送带 `FIN` 的TCP报文，表示自己要断开这个 TCP 连接

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/WechatIMG8.jpeg?raw=true)

第二步：
> `后断开端` 向 `先断开端` 发送带 `ACK` 的TCP报文，表示自己已经知道对方想要断开连接了。

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/WechatIMG9.jpeg?raw=true)

第三步：
> `后断开端` 向 `先断开端` 发送带 `FIN` 的TCP报文，表示自己已经准备好断开连接了，可能有童鞋要问，为什么这个`FIN`为什么不和上面那个`ACK`一起就发送过去了呢？两次分开发送不是增加开销吗？这是因为`后断开端`也需要准备啊。不能你说断开就断开吧，首先我得试一试能不能断开，确定能断开了，我就会发送`FIN`确定。

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/WechatIMG10.jpeg?raw=true)

第四步：
> `先断开端` 向 `后断开端` 发送带 `ACK` 的TCP报文，确认自己已经断开连接，你也可以断开连接了。

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/WechatIMG11.jpeg?raw=true)

我们看一下各状态的状态图：

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/DraggedImage-3.png?raw=true)

解释：

- `FIN_WAIT_1`: 这个就是先断开端发送了`FIN`状态码之后出现的状态。在程序层面来看，就是`Close Scoket`.因为后断开端会马上回复带`ACK`标志位的TCP报文确认，所以这个基本看不到。
- `FIN_WAIT_2`: 在自己发送带`FIN`的TCP报文之后，其实就进入了`FIN_WAIT`，等待对方回复`FIN`,只不过中间有个`ACK`，所以就分为了`FIN_WAIT_1`和`FIN_WAIT_2`
- `CLOSE_WAIT`: 这个表示`Close wait`。就是字面的意思。
- `LAST_ACK`: 这个也是字面的意思。等待最后的`ACK`
- `TIME_WAIT`: 这个是见的最多的。意思就是等待`2MLS`时长之后，就进入CLOSED状态。当然如果是在服务器上面，那么就是销毁了这个TCP连接，当然可以设置kernel参数让此TCP连接不销毁，然后重新被使用。

PS：

2MSL(Maximum Segment Life 报文最大生存时间)：`TIME_WAIT状态停留的时间为2倍的MSL。这样可让TCP再次发送最后的ACK以防这个ACK丢失（另一端超时并重发最后的 FIN），MSL过长会导致无用TIME_WAIT过多，大量的Time_wait会带来一些不好的影响，每个TCP连接都有自己的Transmission Control Block，也就是数据结构，在TIME_WAIT状态的时候这个数据结构还没有被释放。`


	$ sysctl net.ipv4.tcp_fin_timeout  /* 查看MSL */
	net.ipv4.tcp_fin_timeout = 60
	$ cat /proc/sys/net/ipv4/tcp_fin_timeout  /* 查看MSL */
	60
	$ sudo vim /etc/sysctl.conf
	net.ipv4.tcp_fin_timeout = 20  /* 后面数字可以根据情况来 */
	$ sudo sysctl -p

## 三、运维角度的延伸

### 3.1 HTTP持久连接(keepalive)

最后到了解释上面为什么是`先断开连接`和`后断开连接`了。

HTTP1.0的时候，HTTP协议是没有HTTP持久连接 `(keepalive，在后面会不加区别的使用keepalive和持久连接)`这个概念的，基本传输一个`Resocurce`，就需要建立一次连接。HTTP 1.1默认启用的HTTP持久连接能够在`keepalive_timeout`前省去每次传输报文都要建立TCP连接(三次握手)的时间和开销. 

非持久连接：

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/DraggedImage-4.png?raw=true)

持久连接(少了TCP的三次握手和四次断开)：

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/DraggedImage-5.png?raw=true)

(注: 上图我是从 `images.Google.com` 随便找的, 如有侵权请联系 `yanshanchen@hotmail.com`, 立即更换....)

`HTTP1.0`基本可以忽略了，所以这里就出现`keeplive_timeout`就是关键，也就是说`Server`和`Client`谁`keeplive_timeout`先到期，谁就发送`FIN` TCP报文以断开连接。

### 3.2 `keepalive_timeout` 测试

	HTTP keep-alive connection timeouts
	Firefox: 约115秒(定义在about:config中的network.http.keep-alive.timeout)
	Chrome:  约320秒
	Opera:   约120秒
	MSIE:    约60秒(可以在注册表中自定义)
	https://support.microsoft.com/en-us/kb/813827
	
	Nginx:   默认值65秒(keepalive_timeout 65s)

`Firefox` 默认 `HTTP connection keep-alive timeout: 115s`
`Firefox` 在 `about:config` 中的 `network.http.keep-alive.timeout` 可以进行修改 
￼
![](https://chenyanshan.github.io/img/linux/server/tcp_connection/DraggedImage-6.png?raw=true)

`Nginx` 可以在 `/etc/nginx/nginx.conf` 配置配置项 `keepalive_timeout` 来调整默认 `HTTP connection keep-alive timeout`

	$ vim /etc/nginx/nginx.conf
		keepalive_timeout  65;   /* 可以任意修改 */

当`Nginx HTTP connection keep-alive timeout` 为默认的 `65s`,使用默认设置的`Firefox`来访问`Nginx`，测试是否是`Server`端先断开TCP连接，能否出现 `120S (2MSL)` 的 `TIME_WAIT`
￼
![](https://chenyanshan.github.io/img/linux/server/tcp_connection/3C74F383-BEA5-4D58-8310-D934607FFDE4.png?raw=true)

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/0396BD34-44B9-4725-8B84-76FD4CD9AE5D.png?raw=true)

和预料中的一样，出现了`TIME_WAIT`: 
￼

测试将 `Nginx` 超时时长调整为 `120s`, 看是否不出现`TIME_WAIT` 

![](https://chenyanshan.github.io/img/linux/server/tcp_connection/013B3F3D-135B-458E-A504-C70821D0DF67.png?raw=true)
￼
![](https://chenyanshan.github.io/img/linux/server/tcp_connection/269BB0A6-0EC6-4BC5-9AFF-EC8CB13E9E61.png?raw=true)

经过测试，`120s`无用，设置成`130s`然后出现`Client`先断开连接。

如果也是运维，在这个地方就应该思考一下，上面的测试到底说明了什么。

### 3.2 自定义是否启用 `keepalive_timeout` 

上面说HTTP1.1默认启用的是keepalive。`HTTP Hearder`中的`Connection`可以控制,当`Connection`为`close`的时候，就是短连接，当`Connection`为`keepalive`的时候，就是使用长连接。`Client`可以设置，`Server`也可以设置。

先测试`Client`设置`Connection: close`，这里使用最简单的`Telnet`:

	$ telnet 10.21.56.4 80
	HEAD /index.php HTTP/1.1
	Host: 10.21.56.4
	Connection: close
	
	HTTP/1.1 200 OK
	Server: nginx/1.10.1
	Connection: close

为了方便大家查看,我把不是很重要的信息全部都删除掉了。上面就可以很清楚的展示，当`Connection` 为 `close`的时候，双方都会协商使用短连接。

在Server上面进行观测：

	netstat -antl | grep 80 | awk '/^tcp/{sum[$NF]++}END{for (i in sum) {printf "%-20s %d\n",i,sum[i]}}'
	TIME_WAIT            1
	LISTEN               1

发现有一个连接进入`TIME_WAIT`,也就是说就算是`Client`协商使用短连接，主动断开连接的还是`Server`

使用`Firefox`访问网站， Nginx HTTP响应报文 的 `Hearder`

	HTTP/1.1 200 OK
	Server: nginx/1.10.1
	Connection: keep-alive

在`Server`端将`keepailve_timeout`设置为0
	$ vim /etc/nginx/nginx.conf
		keepalive_timeout  0;

使用`Firefox`访问网站， Nginx HTTP响应报文 的 `Hearder`

	HTTP/1.1 200 OK
	Server: nginx/1.10.1
	Connection: close

到这里大家肯定对运维需要掌握的TCP/IP部分有了深入的了解。也能看懂`netstat -antl`中的那些 TCP 状态到底是什么含义了。后面会在此文的基础上讲述一下网络调优。

参考资料：

[The TCP/IP Guide - TCP Connection Establishment Process: The "Three-Way Handshake" ](#)

[The TCP/IP Guide - TCP Connection Termination ](http://www.tcpipguide.com/free/t_TCPConnectionEstablishmentProcessTheThreeWayHandsh.htm)

[Wikipedia - Transmission Control Protocol ](https://en.wikipedia.org/wiki/Transmission_Control_Protocol)

`《TCP/IP详解 卷一：协议》`
