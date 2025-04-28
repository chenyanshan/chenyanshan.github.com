---
layout: page
title:  "corosync&pacemaker组合二"
date:   2016-6-23 22:05:07
categories: HA
tags: HA
---
看不懂的童鞋可以看我的HA理论篇和图形界面配置篇，这样可以对pacemaker和corosync组合使用有个比较深的认知。不然我说的是什么你基本是看不懂的。为了让大家更了解细节，这里就不建立Gorup而直接创建资源，然后使用`位置约束、排列约束、顺序约束`进行管理，

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage.png?raw=true)

创建之后用`verify`检测。

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-1.png?raw=true)

哪里有问题修改哪里。先创建一个简单的VIP。

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-2.png?raw=true)

提示已经存在那就删除重建

再把`stonith`关闭

	crm(live)configure# property stonith-enabled=false

再检测，没问题就提交

	crm(live)configure# verify
	crm(live)configure# commit

退到主模式用`status`查看状态

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-3.png?raw=true)

可以看到VIP已经在web1.itcys.top上面启动了

继续httpd的资源创建

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-4.png?raw=true)

可以看到lsb的资源类型很多。我们选择httpd，上次在`hb_gui`配置的时候大家就知道httpd不需要其他参数，所以这里我们直接创建,然后测试，提交。

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-5.png?raw=true)

集群自动利用所有的Server的性能来实现负载均衡，将VIP和Service启动在不同的节点上面。明显不是我们需要的。这个时候我们就需用`约束`来控制

web1和web2性能差不多，所以我们先用`排列约束`将它们组合到一起就好

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-6.png?raw=true)

Help一下，配置还是挺简单的。

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-7.png?raw=true)

创建排列约束之后明显的资源就到一个节点上面去了。有一点需要注意。在图中的 apacheServer 和 vip 在定义的时候先后顺序对整个资源的启动顺序有很大影响，图中的那条命令的意思就是 apacheServer 根据 vip 来，vip在哪个节点启动了，那么 apacheServer就在哪个节点启动。

现在我们尝试访问一下，

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-8.png?raw=true)

我们再创建`位置约束`将资源移动到web2.itcys.top上面去

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-9.png?raw=true)

help一下，还是挺麻烦的。不过我们之前就已经做过了，现在应该不难。

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-10.png?raw=true)

简单的创建了一个名字为`conn_test_1`的`位置约束`，效果明显。

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-11.png?raw=true)

测试页面。

顺序约束是`order`，不会用的童鞋help一下就好了。

我们最后来定义监控，现在这个状态当资源宕掉之后，集群是不会进行任何处理的。这样肯定是不行的。所以我们再来定义监控

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-12.png?raw=true)

help的结果极其简单。这是我没有想到的。。。。

创建一个监控

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-13.png?raw=true)

关闭httpd之后：

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-14.png?raw=true)

但是过不了多久，服务就会继续启动，80端口被监听

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-15.png?raw=true)

还能访问。

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-16.png?raw=true)

我们让它不能启动试试。

	[root@web2 conf]# mv httpd.conf httpd.conf.bak
	[root@web2 conf]# service httpd stop
	Stopping httpd:                                            [  OK  ]
	[root@web2 conf]# crm status;

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-17.png?raw=true)

资源立马就会转移,这就是监控的作用。

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-18.png?raw=true)

服务还在，只是转移到Web1上面去了。

当然还有之前说过的资源粘性。当位置约束倾向性比较高的节点启动后，资源是否转移回去呢？这个时候就的靠资源粘性了。

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-19.png?raw=true)

	crm(live)configure# rsc_defaults resource-stickiness=-100  //设置当前节点资源粘性为-100.
	crm(live)configure# verify
	crm(live)configure# commit

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-20.png?raw=true)

这就是`资源粘性`的作用

我们最后模仿一下硬件级别的故障转移

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-21.png?raw=true)

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-22.png?raw=true)

我们在web2.itcys.top进行模拟硬件故障，但是到web1.itcys.top上面进行查看却发现没有转移，而是整个集群都故障了。这是为什么呢？

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-23.png?raw=true)

`quorum`，这个概念我在HA架构模型里面说了，这里我就不扯远了，因为2台机器都是一台一票，所以当它们分裂时，是绝对不会出现`quarum`(票数过半的)的。这个时候可以关闭防止集群分裂的这个票数系统

我们重新启动web2

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-24.png?raw=true)

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-25.png?raw=true)

开启这个选项之后再模拟web2故障。

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-26.png?raw=true)

资源粘性让资源又回到了web2

停止web2上面的服务

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-27.png?raw=true)

在web1.itcys.top上面查看

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-28.png?raw=true)

可以看到web2已经离线。但是资源还在运行web1上面运行

浏览器进行查看

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-29.png?raw=true)

配置就这些

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-30.png?raw=true)

PCS的使用方法：PCS和CRMSH一样是一个Client端工具。不过CRMSH是在Suse的，而PCS是Redhat的，这也是为什么CRMSH需要手动安装的原因，虽然我个人感觉易用性上面CRMSH比PCS好了不止一个档次。但是Redhat要这么搞也没办法。不行就手动安装就好了，只要在一台上面安装上CRMSH你就可以摆脱痛苦的PCS。虽然难用，但是还是的好好用一下，

环境可以使用上面提供的`ansible-playbook`直接运行就好，或者把上面的配置全部删除。

1、安装

	[root@web1 crmsh]# yum -y install pcs

大概用法：

	pcs property 
			set     修改属性
			uset    删除
			list    显示所有的属性
		
	pcs resource          设置资源默认属性 
		    list          显示所有资源代理
		    standards     列出所有的资源代理类别
		    providers     显示OCF的providers
		    agents        显示一个类别下的代理
		    describe      显示代理的属性
		    create        创建资源
		 	group add     添加组
		    group remove  删除组中的成员
		    ungroup       删除组，不删除资源
		    move          手动迁移
		    meta          向指定的资源添加额外属性
	
	constraint  约束
			location       位置约束
			colocation     排列约束
			oeder          顺序约束
	 		remove         移除


创建`vip`，设置监控以及定义`on-fail`

	[root@web1 ~]#  pcs resource create vip ocf:heartbeat:IPaddr ip=192.168.100.20 op monitor interval=30s timeout=20s on-fail=restart

创建`apache`

	[root@web1 ~]# pcs resource create apacheService lsb:httpd op monitor interval=30s timeout=20s on-fail=restart

因为我使用`pcs status`一直报错，所以就用crm来查看了。其实crm比pcs好用不知道多少

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-31.png?raw=true)

标准的一个资源运行在一个节点上面。

定义排列约束:

	[root@web1 crmsh]# pcs constraint colocation add apacheService with vip

效果

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-32.png?raw=true)

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-33.png?raw=true)

定义一下位置约束

	[root@web1 crmsh]# pcs constraint location apacheService prefers web2.itcys.top=300

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-34.png?raw=true)

资源立马转移

定义顺序约束

	[root@web1 crmsh]# pcs constraint order vip then apacheService

效果看不出。只要知道配置方法就好。

创建一个组：

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-35.png?raw=true)

删除组中的一个资源：

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/2/DraggedImage-36.png?raw=true)

可以同时删除多个。删除完了组就不存在了

好了 就意思意思就好了。确实难用。。。\<tab\>都不支持。不过help基本能出来。