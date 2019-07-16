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

# 修改root密码
RUN echo "root:123456" | chpasswd

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
    mv /tmp/spark-env.sh $SPARK_HOME/conf/spark-env.sh && \
    mv /tmp/hosts /etc/hosts


EXPOSE 22 9000 9001 8030 8032 8033 8035 8088
CMD ["/usr/sbin/sshd","-D"]

