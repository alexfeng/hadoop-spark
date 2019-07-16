> 作 者：冯向博 
> 介 绍：使用 Docker 进行大数据环境搭建笔记
> 公众号：冯向博的学习笔记

这是在前面几篇使用macOS使用Docker搭建hadoop环境的升级版本。
之前的版本的操作是按照培训时候的虚拟机方式来做的，实际搭建起来要配置的过程比较繁琐。
这个升级版本是在研究了一番Docker后，对之前的hadoop环境搭建复盘后做出来的。

### 目录
1. 环境介绍
2. 计划集群配置
3. 使用Dockerfile来构建的镜像
4. 使用镜像来启动容器
5. 总结

### 一）环境介绍
宿主机环境|容器环境
---|---
mac OS High Sierra | Centos7
Docker Engine version 18.09.2| jdk8
docker-compose version 1.23.2, build 1110ad01|hadoop2.6.5
docker-machine version 0.16.1, build cce350d7|scala2.11.8
 -|spark2.3.3


### 二）计划集群配置
> 集群配置需要3个节点，一个master节点，其他节点都是slave节点

节点 |主机名 | ip 
---|---|---
sp-master|master|172.19.0.100
sp-slave1|slave1|172.19.0.101
sp-slave2|slave2|172.19.0.102


### 三）使用Dockerfile来构建自己的镜像
使用Docker官方的centos镜像，里面什么软件都没有。
我们需要安装基础的一些工具软件wget，which，net-tools
Hadoop依赖ssh、java环境
Spark依赖scala环境
因此我们在官方的Centos镜像之上先构建一个属于hadoop+spark的镜像。

#### 1. 创建Dockerfile
```bash
mkdir hadoop-spark
touch hadoop-spark/Dockerfile
mkdir -p hadoop-spark/config
cd hadoop-spark
vim Dockerfile
```
#### 2. 编辑Dockerfile
> 下面是定义的Dockerfile文件

```bash
FROM centos:7
MAINTAINER by supermvn(supermvn@163.com)

# 使用国内yum源
COPY config/CentOS-Base.repo /etc/yum.repos.d

# 安装 工具
RUN yum install -y openssh-server && \
    yum install -y openssh-clients && \
    yum install -y wget && \
    yum install -y which && \
    yum install -y net-tools

# JDK8下载与安装
RUN cd /usr/local/src && \
    wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" \
    http://download.oracle.com/otn-pub/java/jdk/8u141-b15/336fa29ff2bb4ef291e347e091f7f4a7/jdk-8u141-linux-x64.tar.gz && \
    tar -xzvf jdk-8u141-linux-x64.tar.gz && \
    rm jdk-8u141-linux-x64.tar.gz


# Java PATH
ENV JAVA_HOME /usr/local/src/jdk1.8.0_141
ENV PATH $JAVA_HOME/bin:$PATH

# hadoop 下载与安装
RUN cd /usr/local/src && \
    wget https://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-2.6.5/hadoop-2.6.5.tar.gz && \
    tar -xzvf hadoop-2.6.5.tar.gz && \
    rm hadoop-2.6.5.tar.gz


# hadoop PATH
ENV HADOOP_HOME /usr/local/src/hadoop-2.6.5
ENV PATH $HADOOP_HOME/sbin:$HADOOP_HOME/bin:$PATH

# scala 下载与安装
RUN cd /usr/local/src && \
    wget https://downloads.lightbend.com/scala/2.11.8/scala-2.11.8.tgz && \
    tar -xzvf scala-2.11.8.tgz && \
    rm scala-2.11.8.tgz

# scala PATH
ENV SCALA_HOME /usr/local/src/scala-2.11.8
ENV PATH $SCALA_HOME/bin:$PATH

# spark 下载与安装
RUN cd /usr/local/src && \
    wget "https://mirrors.tuna.tsinghua.edu.cn/apache/spark/spark-2.3.3/spark-2.3.3-bin-hadoop2.6.tgz" && \
    tar -xzvf spark-2.3.3-bin-hadoop2.6.tgz && \
    rm spark-2.3.3-bin-hadoop2.6.tgz

# spark PATH
ENV SPARK_HOME /usr/local/src/spark-2.3.3-bin-hadoop2.6
ENV PATH $SPARK_HOME/bin:$PATH

# ssh 
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
RUN cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

RUN mkdir /var/run/sshd

# hadoop data dir
RUN cd /usr/local/src && \
    mkdir -p hadoop/dfs/namenode && \
    mkdir -p hadoop/dfs/datanode && \
    mkdir -p hadoop/tmp

# 配置文件
COPY config/* /tmp/

RUN mv /tmp/hadoop-env.sh $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    mv /tmp/hdfs-site.xml $HADOOP_HOME/etc/hadoop/hdfs-site.xml && \ 
    mv /tmp/core-site.xml $HADOOP_HOME/etc/hadoop/core-site.xml && \
    mv /tmp/mapred-site.xml $HADOOP_HOME/etc/hadoop/mapred-site.xml && \
    mv /tmp/yarn-site.xml $HADOOP_HOME/etc/hadoop/yarn-site.xml && \
    cp /tmp/slaves $HADOOP_HOME/etc/hadoop/slaves && \
    mv /tmp/slaves $SPARK_HOME/conf/slaves && \
    mv /tmp/spark-env.sh $SPARK_HOME/conf/spark-env.sh


EXPOSE 22 9000 9001 8030 8032 8033 8035 8088
CMD ["/usr/sbin/sshd","-D"]
```

#### 3. 构建镜像
```bash
docker build -t supermvn/hadoop-spark:1.0.0 . -f Dockerfile
```
这个会花费点时间
* pull Centos
* 下载安装基础工具
* 下载安装 jdk
* 下载安装 hadoop
* 下载安装 scala
* 下载安装 spark

### 四）使用镜像来启动容器
1. 编辑hosts文件将地址和主机名写入
```bash
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::0	ip6-localnet
ff00::0	ip6-mcastprefix
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters

172.19.0.100	master
172.19.0.101  slave1
172.19.0.102  slave2
```
2. 创建一个自定义桥接
```bash
docker network create --driver bridge --subnet 172.19.0.0/16 hadoop_net
```
3. 创建master容器
```bash
docker run --privileged  --name sp-master --hostname master -v ~/hadoop-spark/config/hosts:/etc/hosts --net hadoop_net --ip 172.19.0.100 -d -P supermvn/hadoop-spark:1.0.0 /usr/sbin/init
```
4. 创建slave1和slave2容器器
```bash
docker run --privileged  --name sp-slave1 --hostname slave1 -v /Users/mac/hadoop-spark/config/hosts:/etc/hosts --net hadoop_net --ip 172.19.0.101 -d supermvn/hadoop-spark:1.0.0 /usr/sbin/init
docker run --privileged  --name sp-slave2 --hostname slave2 -v /Users/mac/hadoop-spark/config/hosts:/etc/hosts --net hadoop_net --ip 172.19.0.102 -d supermvn/hadoop-spark:1.0.0 /usr/sbin/init
```
5. 在master执行
```bash
hadoop namenode -format

start-all.sh
```
道这里就启动了hadoop

6. 测试hadoop
在master容器中
```bash
hadoop fs -mkdir /input 
hadoop fs -put /tmp/CentOS-Base.repo /input
cd /usr/local/src/hadoop-2.6.5/share/hadoop/mapreduce/
hadoop jar hadoop-mapreduce-examples-2.6.5.jar wordcount /input /output
hadoop fs -cat /output/part-r-00000
```
这个是hadoop进行一个wordcount的例子

7. 测试spark
```bash
cd /usr/local/src/spark-2.3.3-bin-hadoop2.6/bin
spark-shell
```
会看到spark 启动shell

### 五）总结

1. 列出具体的宿主机环境，容器使用的环境。
2. 列出计划集群的配置信息。
3. 如何使用Dockerfile来制作一个定制镜像。
4. 使用定制的镜像来实现hadoop+spark集群容器。

