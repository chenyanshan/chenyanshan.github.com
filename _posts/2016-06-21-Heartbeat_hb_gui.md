---
layout: page
title:  "图形界面配置HA"
date:   2016-6-21 23:05:07
categories: HA
tags: HA
---
这个是前面一篇理论的深入。使用heartbeat实现高可用。
前面准备工作我就不讲过程了

- 1、各节点uname和/etc/hosts同步
- 2、NTP时间同步
- 3、安装Heartbert
- 4、配置Heartbert的ha.cf和authkeys

觉得麻烦的话可以用`ansible`

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage.png?raw=true)

Heartbeart需要安装这四个包：

heartbeat、heartbeat-stonith、heartbeat-pils、heartbeat-gui

准备工作如果不会的话，可以拉到最后，我在那里放了一个链接，是我之前写的blog

注意：需要使用heartbeat-gui必须要使用xshell和Xmanager，xshell对个人用户是免费授权的，但是Xmanager是收费的，这个时候就需要仁者见仁，智者见智了。

配置xshell：
文件--\>属性--\>隧道--\>对勾图上面的选项

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-1.png?raw=true)

这个是重新登录，如果出现下面的报错

	“The remote SSH server rejected X11 forwarding request.”

那就需要在`/etc/ssh/sshd_conf`中启用以下选项

        X11Forwarding yes

如果已经启用了，或者启用了没用。
请安装桌面环境,只需要在一个节点上面安装就好

	yum -y groupinstall "X Windows System"
	yum -y groupinstall "Desktop"

建立`NFS_Server`

	[root@NFS ~]# yum install rpcbind
	[root@NFS ~]# yum -y install nfs-utils
	[root@NFS ~]# mkdir -p /web/sharedir
	[root@NFS ~]# setfacl -m u:apache:rw /web/sharedir
	[root@NFS ~]# vim /etc/exports
	/web/sharedir  192.168.100.0/24(rw)
	[root@NFS ~]# service rpcbind start
	[root@NFS ~]# service nfs start

如果对防火墙和SELinux不是很熟悉的话，建议所有节点关闭iptables和SELinux,当然，这只针对当前实验环境

	service iptables stop
	setenforce 0

关闭Server上面的VIP，httpd，取消nfs的挂载，并将httpd加入开机不自动启动，Heartbeat开机自动启动。


开始配置，配置之前创建用户hacluster并为其设定密码

	[root@web1 ha.d]# hb_gui


![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-3.png?raw=true)

界面图

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-4.png?raw=true)

说一下我们的目标。我们模拟小型公司的Web高可用服务(当然，这个也可以放到大型架集群架构中去，不过要结合其他负载均衡或者高可用软件了)，访问不多，但是对在线时间要求又比较高。当然，你要是觉得架构图中浪费了一台Server，其实也可以将改NFS放到Web3上，不扯太远，这篇架构应用场景不是针对当前场景的，所以不要对号入座。vip指虚拟ip。

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-5.png?raw=true)

我再解释一下图，图中的意思很明确，使用DNS做负载均衡，负责将一个域名解析成两个IP，Web1，Web2，Web3由Heartbeat组成高可用集群，web3.itcys.top负责在web1.itcys.top或者web2.itcys.top挂掉的时候顶替其位置，其实就是将服务起来，将VIP1加到自己身上，把nfs挂载一下，把httpd服务启动起来就可以了



点击最上面一排中的那个+号，选择Group。因为Group内部是直接就可以定义资源只在同一个Server上面启动。启动的先后顺序也是创建资源的顺序，当然在nfs+apache+vip这个组合上面并不需要谁先谁后，其实都一样

组名字自定义

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-6.png?raw=true)

取个Resource ID，然后选择RA，再之后填写参数

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-7.png?raw=true)

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-8.png?raw=true)

LSB风格只需要接收start，stop，status就行，所以并不需要任何参数。

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-9.png?raw=true)

创建第二组`Web_group_2`

除了VIP中的iflabel不一样之外(防止挂2台的情况发生，这个参数是定义网卡别名，1就是eth0:1），当然Resource ID也要不同。

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-10.png?raw=true)

创建位置约束(资源更倾向于那个节点上)：

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-11.png?raw=true)

一共有4个。

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-12.png?raw=true)

Resource指的是针对哪个IP，Score指的是倾向性有多大。INFINITY(无穷大)指只要指定的机器不出问题就不转移。加上expressions语句之后，组合起来就是：`Web_group_1`中的资源只要`uname`等于`web1.itcys.top`的Server不出问题，那么就不转移

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-13.png?raw=true)

`Web_group_2`中的资源只要`uname`等于`web2.itcys.top`的Server不出问题，那么就不转移

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-14.png?raw=true)

`Web_group_1`中的资源在当前集群没有存在位置约束大于100的话。就把资源转移给`uname`等于`web3.itcys.top`的Server

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-15.png?raw=true)

`Web_group_2`中的资源在当前集群没有存在位置约束大于100的话。就把资源转移给`uname`等于`web3.itcys.top`的Server

![](https://chenyanshan.github.io/img/linux/server/hb_gui/DraggedImage-16.png?raw=true)

好了，测试我就不贴上来了，反正我这边是没有任何问题，关闭web1，资源会自动转移到web3.而不会转移到web2，反之亦然，当然2个都关闭了，就肯定落在剩下的那个身上。而当web1或者web2重新上线，资源还是会回到web1和web2

准备工作可以按照这篇的准备工作来:http://itcys.top/architecture/2016/06/18/LVS_3.html
