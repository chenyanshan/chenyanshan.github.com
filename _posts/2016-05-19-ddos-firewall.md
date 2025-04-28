---
layout: page
title:  "简单实现自动防御DDOS"
date:   2016-4-19 01:52:07
categories: linux
tags: linux
---
  之前在群里聊天的时候听到一群友在抱怨前任是不是得罪人了，现在公司网站天天受到DDOS攻击，而且对方肉鸡很多，都好像正常访问者一样，根本就无从判断。助人为乐是我这样的现代帅小伙经常做的事情(我自己都想吐了)，于是我便到他那里问来了日志(说的简单，其实发了几个邮件，等了几天才拿到日志的，而且只是一个小日志)，当然，在这之前我向其承诺了发在公共场合的图片及文字不会涉及到日志的具体内容。
  日志拿到经过半个小时监测就基本有了思路，可能是那个群友对http协议不和web服务日志不怎么了解的原因，他认为那个很复杂的问题其实比较简单。

直接进入主题：

## 思路(关键是这个)

 一，分析日志(日志太少，分析方式和正常不一样)：

 - 按访问次数对IP进行排序

 - 从访问次数最高的IP依次对下面三项进行分析


	1.请求资源
	2.响应码
	3.跳转链接


 - 对分析出来的异常IP再进行分析

 二，记录日志

 - 不确定是否为攻击者的异常IP记录日志，

 - 确定的攻击者直接加入iptables并记录日志

 三，设置黑白名单和恢复机制

 - 设置白名单，将白名单用户排除最开始的排序

 - 设置恢复时间，差不多到时间就将IP从iptables排除，重复3次将加入黑名单，不再恢复，直到IP被手动从黑名单删除


因为群友公司网站太小，我又比较懒，所以得出思路我就只做到记录日志，并没有将黑白名单和恢复机制加入其中，如果是大型网站，必须要有恢复机制，连黑名单都不能有。当然要是大型公司，那应该就不需要用这样原始的防火墙组合套件了



1.看日志内容(前缀192.168是我改的)

	[root@localhost ddos_nginx_log]# tail shop_nginx.log 
	192.168.108.141 - - [16/May/2016:23:58:55 +0800] "GET /jjsp-485-4-0-0-0.html HTTP/1.1" 200 10513 "-" "Mozilla/5.0 (compatible; Baiduspider/2.0; +http://www.baidu.com/search/spider.html)"
	192.168.165.197 - - [16/May/2016:23:58:56 +0800] "GET /qz-0-2-0-0-0.html HTTP/1.1" 200 13786 "-" "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Win64; x64; Trident/5.0; .NET CLR 2.0.50727; SLCC2; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; InfoPath.3; .NET4.0C; Tablet PC 2.0; .NET4.0E)"
	192.168.165.11 - - [16/May/2016:23:58:56 +0800] "GET /20790/product.html HTTP/1.1" 200 4241 "-" "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Win64; x64; Trident/5.0; .NET CLR 2.0.50727; SLCC2; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; InfoPath.3; .NET4.0C; Tablet PC 2.0; .NET4.0E)"
	192.168.71.70 - - [16/May/2016:23:58:57 +0800] "GET /16682 HTTP/1.1" 301 5 "-" "Mozilla/5.0 (compatible; Baiduspider/2.0; +http://www.baidu.com/search/spider.html)"
	192.168.71.31 - - [16/May/2016:23:58:58 +0800] "GET /10189/news-24575.html HTTP/1.1" 200 6208 "-" "Mozilla/5.0 (compatible; Baiduspider/2.0; +http://www.baidu.com/search/spider.html)"
	192.168.182.87 - - [16/May/2016:23:58:59 +0800] "GET /20550/news-24951.html HTTP/1.1" 200 17055 "-" "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:2.0b13pre) Gecko/20110307 Firefox/4.0b13"
	192.168.71.81 - - [16/May/2016:23:58:59 +0800] "GET /16682/ HTTP/1.1" 200 8474 "-" "Mozilla/5.0 (compatible; Baiduspider/2.0; +http://www.baidu.com/search/spider.html)"

日志格式为combined，信息比较多，找出来的攻击者IP也比较准确

![][image-1]

然后我们就可以针对访问量多的IP进行其他分析了,因为我之前就分析过了，我就直接拿出一个有问题的直接分析过去了。

分析异常IP的http响应码是否异常

![][image-2]

看着无异常

那资源请求呢？

![][image-3]

还是无异常

查看跳转链接

![][image-4]

直接就找出来了，不过这样的情况只能适合当前场景，到其他场景就应该不能实现了

![][image-5]

效果

![][image-6]

其实这样写总感觉不好，不过只是一个小脚本，应付一下小场景，应该是够用了。
再之后就是iptables了，那就比较简单了

![][image-7]

当然这样肯定是不好的，不过对于小型网站勉强也够用，对于中型网站，我在上面已经给出思路，还是比较简单的。。

脚本：https://github.com/chenyanshan/sh/blob/master/ddos_firewall.sh

[image-1]:	https://chenyanshan.github.io/img/linux/sh/ddos_iptables/2%E7%8E%B0%E8%B1%A1_1.png?raw=true
[image-2]:	https://chenyanshan.github.io/img/linux/sh/ddos_iptables/3code.png?raw=true
[image-3]:	https://chenyanshan.github.io/img/linux/sh/ddos_iptables/3.png?raw=true
[image-4]:	https://chenyanshan.github.io/img/linux/sh/ddos_iptables/4code2.png?raw=true
[image-5]:	https://chenyanshan.github.io/img/linux/sh/ddos_iptables/5shell_2.png?raw=true
[image-6]:	https://chenyanshan.github.io/img/linux/sh/ddos_iptables/7.jpg?raw=true
[image-7]:	https://chenyanshan.github.io/img/linux/sh/ddos_iptables/8.jpg?raw=true	
