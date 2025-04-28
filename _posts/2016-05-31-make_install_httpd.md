---
layout: page
title:  "模式化编译安装"
date:   2016-4-31 8:52:07
categories: Make
tags: Make
---

很多人只是知道编译安装，甚至很多已经在工作了的，时常编译安装软件的运维工作人员对标准编译安装的完整流程还是不了解，这里就借助编译安装Apache将这套流程完全过一遍(其实是不想只编译安装Apache，网上一搜索一大把)。编译安装完全步骤，其中一些细节未曾修饰，但是也完全可以达到：

> - 定制安装(标配)
> - 使用service启动关闭服务
> - 加入chkconfig开机启动项
> - 使用man查看服务文档
> - 使用配置文件文件更改启动选项
> - 导出头文件
> - 导出库文件

其实这基本就是rpm安装的时候。rpm安装包比我们多做的事情了。
不扯太多，直接进入主题：

# －，编译安装Apache

 1.1 编译安装apr apr-util

![](https://chenyanshan.github.io/img/linux/server/Httpd/2%E5%AE%89%E8%A3%85%E5%9F%BA%E7%A1%80%E5%8C%85.jpg?raw=true)

 1.2 编译安装Apache，选项可以根据自己需要的来

![](https://chenyanshan.github.io/img/linux/server/Httpd/3-2New%E7%BC%96%E8%AF%91%E4%BB%A3%E7%A0%81.jpg?raw=true)

 1.3 最常见错误解决办法

![](https://chenyanshan.github.io/img/linux/server/Httpd/5-%E7%AC%AC%E4%BA%8C%E6%AC%A1%E6%8A%A5%E9%94%99.jpg?raw=true)

像这次报错OpenSSL版本过低的问题，我一开始接触编译安装的时候，也是各种想不通，所以我在这里告诉初学者：一般编译安装报的软件问题，yum安装其devel(开发)包就行了，所以这里我就毫不犹豫直接选择安装了openssl-devel。当然这里就是openssl-devel的包的问题。

# 二，库文件和头文件导出

 2.1 导出头文件

![](https://chenyanshan.github.io/img/linux/server/Httpd/6-%E5%AF%BC%E5%87%BA%E5%BA%93%E6%96%87%E4%BB%B6.jpg?raw=true)

 2.2 导出库文件

![](https://chenyanshan.github.io/img/linux/server/Httpd/7-%E5%AF%BC%E5%87%BA%E5%A4%B4%E6%96%87%E4%BB%B6.jpg?raw=true)

头文件和库文件也像PATH环境变量一样，它只在规定的地方寻找自己的内容。

# 三，后续配置

 3.1 让服务能支持man文档

- 在配置文件中添加配置项

![](https://chenyanshan.github.io/img/linux/server/Httpd/8-Man%E6%96%87%E4%BB%B6.jpg?raw=true)

- 测试是否能使用

![](https://chenyanshan.github.io/img/linux/server/Httpd/9-Man%E6%B5%8B%E8%AF%95.jpg?raw=true)

 3.2 添加环境变量

![](https://chenyanshan.github.io/img/linux/server/Httpd/11-%E7%8E%AF%E5%A2%83%E5%8F%98%E9%87%8F.jpg?raw=true)

 3.3 添加启动脚本,在/etc/rc.d/init.d/下面建立httpd文件

![](https://chenyanshan.github.io/img/linux/server/Httpd/12-%E8%84%9A%E6%9C%AC.png?raw=true)

写在/etc/rc.d/init.d下面的脚本都可以被service调用，也就是为什么要建立httpd名字的脚本的名字的原因，脚本名字是什么，就要调用什么

/etc/rc.d/init.d里面的脚本基本都有一定的规范，建议做运维的朋友还是去了解一下。

这个脚本是我半写半抄的，基本上随便拷贝一个过来，修改修改就可以用。脚本我会放在最下面

 3.4 加入chkconfig自动开机项

![](https://chenyanshan.github.io/img/linux/server/Httpd/13-2%20chkconfig.jpg?raw=true)

 3.5 /etc/sysconfig/下面建立配置文件

![](https://chenyanshan.github.io/img/linux/server/Httpd/13-:etc:sysconfig:httpd%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6.jpg?raw=true)

这个配置文件由/etc/rc.d/init.d/httpd脚本调用。

你还可以像selinux定义的时候还加入提示信息

![](https://chenyanshan.github.io/img/linux/server/Httpd/14-%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6selinux.jpg?raw=true)

 3.6 service启动测试

![](https://chenyanshan.github.io/img/linux/server/Httpd/15-%E5%90%AF%E5%8A%A8%E6%B5%8B%E8%AF%95%E6%B5%8B%E8%AF%95.jpg?raw=true)

浏览器测试

![](https://chenyanshan.github.io/img/linux/server/Httpd/16-%E6%B5%8F%E8%A7%88%E5%99%A8%E6%B5%8B%E8%AF%95.jpg?raw=true)

到这里已经完成了。大概就是这样，脚本那块Linux模块化的思想体现的比较严重，当然这也是软件架构设计中高内聚低耦合的体现。由于这整篇总结的是比较重要的一个点，所以用图讲述的比较多。感觉有图还是好些。。。原理啥的也不扯了，扯下去没完没了了～

最后还说一下：
如果你还是Linux运维学习人员，上面的东西你不怎么了解的话，那你就应该深入了解一下这一块了，毕竟这个是基础。
如果你现在已经工作了，对这个还不怎么了解，那就建议你抽出大量的时候补一下基础内容。
当然不是学我这篇blog的内容。我这篇blog就讲了实现，完全没讲原理，要真想把我这个当成学习模版的话，那就等基础过的差不多了，再回过头来看一下就是了～

httpd脚本:https://github.com/chenyanshan/sh/blob/master/httpd
