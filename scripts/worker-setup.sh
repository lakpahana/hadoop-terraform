#!/bin/bash
set -e
set -x

# Update system
apt-get update && apt-get upgrade -y

# Install Java
apt-get install -y openjdk-8-jdk

# Set JAVA_HOME
JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
echo "export JAVA_HOME=$JAVA_HOME" | tee -a /etc/profile.d/java.sh /etc/environment
echo "export PATH=\$JAVA_HOME/bin:\$PATH" | tee -a /etc/profile.d/java.sh /etc/environment
chmod +x /etc/profile.d/java.sh
source /etc/profile.d/java.sh

# Verify Java installation
if [ ! -d "$JAVA_HOME" ]; then
    echo "Java installation failed"
    exit 1
fi

# Create hadoop user
useradd -m -s /bin/bash hadoop || echo "User exists"
echo "hadoop ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set JAVA_HOME for hadoop user
echo "export JAVA_HOME=$JAVA_HOME" >> /home/hadoop/.bashrc
echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /home/hadoop/.bashrc

# Download and extract Hadoop
cd /opt
wget https://dlcdn.apache.org/hadoop/common/hadoop-3.4.1/hadoop-3.4.1.tar.gz || exit 1
tar xzf hadoop-3.4.1.tar.gz || exit 1
mv hadoop-3.4.1 hadoop || exit 1
chown -R hadoop:hadoop /opt/hadoop

# Set environment variables
echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64' >> /home/hadoop/.bashrc
echo 'export HADOOP_HOME=/opt/hadoop' >> /home/hadoop/.bashrc
echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin' >> /home/hadoop/.bashrc
echo 'export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop' >> /home/hadoop/.bashrc

# Configure core-site.xml
cat > /opt/hadoop/etc/hadoop/core-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://${master_ip}:9000</value>
    </property>
</configuration>
EOF

# Configure hdfs-site.xml
cat > /opt/hadoop/etc/hadoop/hdfs-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>/opt/hadoop/data/dataNode</value>
    </property>
</configuration>
EOF

# Configure mapred-site.xml
cat > /opt/hadoop/etc/hadoop/mapred-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.jobtracker.address</name>
        <value>${master_ip}:54311</value>
    </property>
</configuration>
EOF

# Configure yarn-site.xml
cat > /opt/hadoop/etc/hadoop/yarn-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
        <value>org.apache.hadoop.mapred.ShuffleHandler</value>
    </property>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>${master_ip}</value>
    </property>
</configuration>
EOF

# Create data directory
mkdir -p /opt/hadoop/data/dataNode
chown -R hadoop:hadoop /opt/hadoop

# Start DataNode service
su - hadoop -c "/opt/hadoop/sbin/hadoop-daemon.sh start datanode"
