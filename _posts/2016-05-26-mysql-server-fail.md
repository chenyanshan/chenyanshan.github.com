---
layout: page
title: "一开发环境的恢复"
date:   2016-4-26 01:52:07
categories: linux
tags: linux
---

又是一群友，在群里说自己电脑在停电之后重启，虚拟机就起不来了。环境和数据都在上面
帮她用TeamViewer弄着实在蛋疼，她就说发过来，我就愣了，这么大。发过来？不过大家都知道我喜欢助人为乐，然后我也没说啥，就接下了.

![](https://chenyanshan.github.io/img/linux/server/mysql_server_fail/image1.png?raw=true)

发到百度云净10个G。幸好我有个盗版的百度云客户端，不然我还真不想50k/s的速度下载10G的东西。

下载速度还是刚刚的。下载之后解压。

![](https://chenyanshan.github.io/img/linux/server/mysql_server_fail/image2.png?raw=true)

用PD打开还需要类似转码的步骤。

![](https://chenyanshan.github.io/img/linux/server/mysql_server_fail/image3.png?raw=true)

启动之后傻眼了

![](https://chenyanshan.github.io/img/linux/server/mysql_server_fail/image4.png?raw=true)

什么鬼，看不懂。。不过没关心。。来思路！

## 思路：

起不来，可能是Grub引导的问题，在启动的时候重写一下就好

要是系统出问题，那就没办法了！
只能挂载数据磁盘到其他虚拟机，
将虚拟机内部的数据拷贝出来。

好了，我不是啥数据恢复工程师，再多也不会了


开机转了一会，没看到啥有价值的数据。
关机，用一台虚拟机挂载上硬盘
启动。。
查看磁盘信息，sdc1是boot分区。

![](https://chenyanshan.github.io/img/linux/server/mysql_server_fail/image4.png?raw=true)

那就直接挂载/dev/sdc2

![](https://chenyanshan.github.io/img/linux/server/mysql_server_fail/image5.png?raw=true)

报错 
	
	mount: unknown filesystem type 'LVM2_member'

LVM,那就检测一下咯，

![](https://chenyanshan.github.io/img/linux/server/mysql_server_fail/image6.png?raw=true)

果然一检测就出来

找到数据盘。提示不可用，

![](https://chenyanshan.github.io/img/linux/server/mysql_server_fail/image6.png?raw=true)

那就修复咯。为了让别人好找到这2个错误，所以这个地方就不用图片了
	
	[root@localhost ~]# xfs_repair /dev/centos/root 
	Phase 1 - find and verify superblock...
	Phase 2 - using internal log
	        - zero log...
	ERROR: The filesystem has valuable metadata changes in a log which needs to
	be replayed.  Mount the filesystem to replay the log, and unmount it before
	re-running xfs_repair.  If you are unable to mount the filesystem, then use
	the -L option to destroy the log and attempt a repair.
	Note that destroying the log may cause corruption -- please attempt a mount
	of the filesystem before doing this.

报错，按照提示使用－L重建日志

	[root@localhost yum.repos.d]# xfs_repair -L /dev/sdb1
	xfs_repair: cannot open /dev/sdb1: Device or resource busy
	[root@localhost yum.repos.d]# xfs_repair -L /dev/centos/root 
	Phase 1 - find and verify superblock...
	Phase 2 - using internal log
	        - zero log...
	ALERT: The filesystem has valuable metadata changes in a log which is being
	destroyed because the -L option was used.
	        - scan filesystem freespace and inode maps...

挂载

![](https://chenyanshan.github.io/img/linux/server/mysql_server_fail/image7.png?raw=true)

然后在里面找到数据库，PHP代码啥的。当然这些个都是别人的，不好展示
 
摸索过程在下列blog中获得了帮助：

[http://www.cnblogs.com/xiaoyu1005/archive/2013/05/20/3088586.html](#)

[http://www.2cto.com/os/201308/238435.html](http://www.2cto.com/os/201308/238435.html)

[http://qhy.cn/node/430](http://qhy.cn/node/430)

[http://www.xitongzhijia.net/xtjc/20141212/32518.html](http://www.xitongzhijia.net/xtjc/20141212/32518.html)

其实就看了一篇的，不过既然都差不多，就都放这里。查找这个错误才到这里的，可以直接就过去这些链接。里面有的讲的比较详细
