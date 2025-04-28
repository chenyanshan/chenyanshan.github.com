---
layout: page
title:  "corosync&pacemaker组合一"
date:   2016-6-23 17:05:07
categories: HA
tags: HA
---
使用corosync v1和pacemaker结合使用，也就是用corosync替换掉heartbeat。之前HA高可用模型那篇中就说过，Messaging提供API供CRM调用，也就是说CRM只要能调用Messaging的API。那它们之间就能结合使用，corosync和pacemaker就是这样一种关系

我的环境是Centos 6.7，要是和我环境不一样的话，安装部分有些地方应该会不一样。

基础环境的搭建：

为了排除其他因素影响，iptables和selinux都应该关闭：

	[root@web1 ~]# service iptables stop
	iptables: Setting chains to policy ACCEPT: filter          [  OK  ]
	iptables: Flushing firewall rules:                         [  OK  ]
	iptables: Unloading modules:                               [  OK  ]
	[root@web1 ~]# setenforce 0

1、主机名字和解析名字对应

	[root@web2 ~]# cat /etc/hosts; uname -n; cat /etc/sysconfig/network
	127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
	::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
	192.168.100.80  web1.itcys.top
	192.168.100.79  web2.itcys.top
	web2.itcys.top
	NETWORKING=yes
	HOSTNAME=web2.itcys.top

2、时间同步。可以一台作为时间服务器，一台作为客户端。也可以同步cn.ntp.org.cn


时间服务器

	[root@web1 ～]# yum -y install ntp
	[root@web1 ～]# vim /etc/ntp.conf    //在server那几行后面加入下面几句
	server 127.127.1.0
	fudge 127.127.1.0 stratum 10
	[root@web1 ～]# service ntpd start
	--------------------------------------------------------
	[root@web2 ~]# yum -y install ntpdate
	[root@web2 ~]# ntpdate web1.itcys.top
	23 Jun 20:17:52 ntpdate[10551]: adjust time server 192.168.100.80 offset -0.000218 sec

或者也可以

	[root@web1 ～]# yum -y install ntpdate
	[root@web1 ～]# ntpdate cn.ntp.org.cn
	－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－－
	[root@web2 ～]# yum -y install ntpdate
	[root@web2 ～]# ntpdate cn.ntp.org.cn


基础环境搭建好了。那么下面就可以进行安装了


1、先安装corosync (2个node都需要安装)

	[root@web1 ~]# yum -y install corosync

2、安装pacemaker (2个node都需要安装)

	[root@web1 ~]# yum -y install pacemaker


3、安装CRMSH配置接口客户端 (只需要在一个node上面安装就行)

	[root@web1 ~]# yum -y install pssh
	[root@web1 ~]# yum -y install python-parallax-1.0.1-14.1.noarch.rpm
	[root@web1 ~]# yum -y install crmsh-scripts-2.2.1-1.2.noarch.rpm
	[root@web1 ~]# yum -y install crmsh-2.2.1-1.2.noarch.rpm          


4、修改配置文件

	[root@web1 ~]# cat /etc/corosync/corosync.conf | egrep -v "#"
	compatibility: whitetank    //是否兼容0.8以前的版本
	totem {
		version: 2             //版本
		secauth: on            //安全认证是否开启
		threads: 0             //线程数，0表示默认
		interface {
			ringnumber: 0      //环号码，防止一台主机两网卡，一网卡发，一网卡接到自己发出的消息
			bindnetaddr: 192.168.100.0   //当前地址的网络地址
			mcastaddr: 239.255.1.1       //组播地址
			mcastport: 5405              //监听的端口
			ttl: 1
		}
	}
	logging {
		fileline: off
		to_stderr: no  
		to_logfile: yes       //是否使用自己的日志文件
		logfile: /var/log/cluster/corosync.log
		to_syslog: no         //是否纪录进系统日子
		debug: off
		timestamp: on         //是否开启时间戳
		logger_subsys {
			subsys: AMF
			debug: off
		}
	}
	service {
		name: pacemaker    //配套使用的软件
		ver: 1             //{0|1} 0表示corosync启动，pacemaker自动会启动，1表示需要手动启动
	}
	aisexec { 
	        user: root
	        group: root
	}


5、创建认证密钥

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/1/DraggedImage.png?raw=true)

提示这个是说明你随机数不够用，可以一直敲键盘，随机数就会慢慢增多，基本上敲一会儿就行了。

6、同步配置文件

	[root@web1 corosync]# scp -r /etc/corosync/{authkey,corosync.conf} web2.itcys.top:/etc/corosync//etc/corosync/

7、启动集群(2个节点上面都需要运行)

	[root@web1 ~]# service corosync start
	Starting Corosync Cluster Engine (corosync):               [  OK  ]
	[root@web1 ~]# service pacemaker start
	Starting Pacemaker Cluster Manager                         [  OK  ]
 
8、查看集群状态

	[root@web1 ~]# crm status
	Last updated: Wed Jun 22 22:31:42 2016
	Last change: Wed Jun 22 22:04:14 2016
	Stack: classic openais (with plugin)
	Current DC: web1.itcys.top - partition with quorum
	Version: 1.1.11-97629de
	2 Nodes configured, 2 expected votes
	0 Resources configured
	
	
	Online: [ web1.itcys.top web2.itcys.top ]
	
	Full list of resources:

#使用`ansible`进行统一管理也是一种比较好的方式

基础环境搭建好之后。就可以运行剧本了

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/1/DraggedImage-1.png?raw=true)

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/1/DraggedImage-2.png?raw=true)

可以看到一些细节还是提示使用模版，不过基本上环境已经搭建好了。这个playbook还可以进行扩建。要是实际生产环境，那么其实可以先可以创建一个按照IP地址规划主机名的脚本，然后穿过去运行一下。其他的就更加容易实现了。

配置文件出了点问题，使用playbook里面的tags修改一下

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/1/DraggedImage-3.png?raw=true)

直接就可以了。

![](https://chenyanshan.github.io/img/linux/server/corosync+pacemaker/1/DraggedImage-4.png?raw=true)

搭建完成了，后面就是管理了。管理是在下一篇

文章中用到的需要软件和`playbook`

yaml:  https://github.com/chenyanshan/sh/blob/master/corosync_pacemaker_pcs.yaml

Packages:  https://github.com/chenyanshan/Software/tree/master/crmsh
