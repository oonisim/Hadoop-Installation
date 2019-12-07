Spark/Hadoop YARN cluster deployment using Ansible
=========

Approach
------------
* Dependency should be injected. 
* Separation of concerns - Each module must not know about the details of other modules.

AWS Network Topology
------------
Simple 1 master + 2 workers (can be increased by a parameter) in a VPC subnet, to be created by the Ansible playbooks.

<img src="https://github.com/oonisim/Apache-Spark-Installation/blob/master/Images/AWS.png">

Repository Structure
------------

### Overview

Ansible playbooks and inventories under the Git repository.

```
.
├── cluster         <---- Spark cluster installation home (AWS+Spark)
│   ├── ansible     <---- Ansible playbook directory
│   │   ├── aws
│   │   │   ├── ec2
│   │   │   │   ├── creation         <---- Module to setup AWS
│   │   │   │   └── operations
│   │   │   ├── conductor.sh
│   │   │   └── player.sh
│   │   └── spark
│   │       ├── 01_prerequisite      <---- Module to setup Ansible pre-requisites
│   │       ├── 02_os                <---- Module to setup OS to install Spark
│   │       ├── 21_spark       <---- Module to setup Spark cluster
│   │       ├── 51_datadog           <---- Module to setup datadog monitoring (option)
│   │       ├── conductor.sh         <---- Script to conduct playbook executions
│   │       └── player.sh            <---- Playbook player
│   ├── conf
│   │   └── ansible          <---- Ansible configuration directory
│   │       ├── ansible.cfg  <---- Configurations for all plays
│   │       └── inventories  <---- Each environment has it inventory here
│   │           ├── aws      <---- AWS/Spark environment inventory
│   │           ├── local    <---- local environment inventory
│   │           └── template
│   └── tools
├── master        <---- Spark master node data for run_Spark.s created by setup_aws.sh or update manally.
├── setup.sh      <---- Run setup_aws.sh and run_Spark.sh
├── setup_aws.sh  <---- Run AWS setups
└── run.sh        <---- Run setups
```

#### Module and structure

Module is a set of playbooks and roles to execute a specific task e.g. 03_Spark_setup is to setup a Spark cluster. Each module directory has the same structure having Readme, Plays, and Scripts.
```
03_Spark_setup/
├── Readme.md         <---- description of the module
├── plays
│   ├── roles
│   │   ├── common    <---- Common tasks both for master and workers
│   │   ├── master    <---- Setup master node
│   │   ├── user      <---- Setup Spark administrative users on master
│   │   ├── worker    <---- Setup worker nodes
│   ├── site.yml
│   ├── masters.yml   <--- playbook for master node
│   └── workers.yml   <--- playbook for worker nodes
└── scripts
    └── main.sh       <---- script to run the module (each module can run separately/repeatedly)
```
---

# Preparations

## Configurations (Ansible master)
### Environment variables

Update hadoop_variables.sh and spark_variables.sh so that ./installation/_setup_env_cluster.sh setups the environment variables for the installation.
```
export $(cat ${DIR}/conf/ansible/inventories/${TARGET_INVENTORY}/env/hadoop/env/hadoop_variables.sh | grep -v '^#' | xargs)
export $(cat ${DIR}/conf/ansible/inventories/${TARGET_INVENTORY}/env/spark/env/spark_variables.sh   | grep -v '^#' | xargs)
```

AWS target creation creates the files and specify the location to save these files at runtime.

### Hadoop 

Update the configuration file to set:
* HADOOP_VERSION
* HADOOP_PACKAGE_CHECKSUM

```
installation/conf/ansible/inventories/${TARGET_INVENTORY}/group_vars/all/21.hadoop.yml
```

### SPARK

* SPARK_VERSION
* SPARK_PACKAGE_CHECKSUM
* SPARK_SCALA_VERSION  
Set to the Scala versoin used to compile the Spark package)

## For AWS

Have AWS access key_id, secret, and an AWS SSH keypair PEM file. MFA should not be used (or make sure to establish a session before execution).

### On Ansible master host

#### AWS CLI
Install AWS CLI and set the environment variables.

* AWS_ACCESS_KEY_ID
* AWS_SECRET_ACCESS_KEY
* EC2_KEYPAIR_NAME
* REMOTE_USER        <---- AWS EC2 user (centos for CentOs, ec2-user for RHEL)

#### Ansible
Have Ansible (2.4.1 or later) and Boto to be able to run AWS ansible features. If the host is RHEL/CentOS/Ubuntu, run below will do the job.

```
(cd ./cluster/ansible/Spark/01_prerequisite/scripts && ./setup.sh)
```

Test the Ansible dynamic inventory script.
```
conf/ansible/inventories/aws/inventory/ec2.py
```

#### SSH
Configure ssh-agent and/or .ssh/config with the AWS SSH PEM to be able to SSH into the targets without providing pass phrase. Create a test EC2 instance and test.

```
eval $(ssh-agent)
ssh-add <AWS SSH pem>
ssh ${REMOTE_USER}@<EC2 server> sudo ls  # no prompt for asking password

```

#### Datadog (optional)
Create a Datadog trial account and set the environment variable DATADOG_API_KEY to the [Datadog account API_KEY](https://app.datadoghq.com/account/settings#api). The Datadog module setups the monitors/metrics to verify that Spark is up and running, and can start monitoring and setup alerts right away.

#### Ansible inventory

Set environment (or shell) variable TARGET_INVENTORY=aws. The variable identifies the Ansible inventory **aws**  (same with ENV_ID in env.yml) to use.

---

# Run
Run ./setup.sh to run all at once (create AWS environment, setup Hadoop/Spark cluster and test an application) or go through the configurations and executions step by step below.

## Configurations

### Parameters

Parameters for an environment are all isolated in group_vars of the environment inventory. Go through the group_vars files to set values.

```
.
├── conf    <----- CONF_DIR environment variable
│   └── ansible
│      ├── ansible.cfg
│      └── inventories
│           └── aws
│               ├── group_vars
│               │   ├── all             <---- Configure properties in the 'all' group vars
│               │   │   ├── env.yml     <---- Enviornment parameters e.g. ENV_ID to identify and to tag configuration items
│               │   │   ├── server.yml  <---- Server parameters
│               │   │   ├── aws.yml     <---- e.g. AMI image id, volume type, etc
│               │   │   ├── spark.yml   <---- Spark configurations
│               │   │   └── datadog.yml
│               │   ├── masters         <---- For master group specifics
│               │   └── workers
│               └── inventory
│                   ├── ec2.ini
│                   ├── ec2.py
│                   └── hosts           <---- Target node(s) using tag values (set upon creating AWS env)
├── tools   <----- TOOL_DIR environment variable 
```

#### EC2_KEYPAIR_NAME

Set the AWS SSH keypair nameto **EC2_KEYPAIR_NAME** enviornment variable and in aws.yml.

#### REMOTE_USER
Set the default Linux account (centos for CentOS EC2) that can sudo without password as the Ansible remote_user to run the playbooks If using another account, configure it and make sure it can sudo without password and configure .ssh/config.

#### ENV_ID

Set the inventory name _aws_ to ENV_ID in env.yml which is used to tag the configuration items in AWS (e.g. EC2). The tags are then used to identify configuration items that belong to the enviornment, e.g. EC2 dynamic inventory hosts.

#### Master node information
Set **private** AWS DNS name and IP of the master node instance. If setup_aws.sh is used, it creates a file **master** which includes them and run_Spark.sh uses them. Otherwise set them in env.yml and as environment variables after having created the AWS instances.

* MASTER_HOSTNAME
* MASTER_NODE_IP

#### SPARK_ADMIN and HADOOP_USERS
Set an account name to SPARK_ADMIN in server.yml. The account is created by a playbook via HADOOP_USERS in server.yml. Set an encrypted password in the corresponding field. Use [mkpasswd as explained in Ansible document](http://docs.ansible.com/ansible/latest/faq.html#how-do-i-generate-crypted-passwords-for-the-user-module).


Executions
------------
Make sure the environment variables are set.

Environment variables:
* AWS_ACCESS_KEY_ID
* AWS_SECRET_ACCESS_KEY
* EC2_KEYPAIR_NAME
* REMOTE_USER
* DATADOG_API_KEY
* CONF_DIR  <--- configuration folder
* TOOL_DIR  <--- tools folder

Set TARGET_INVENTORY=aws variable which identifies the Ansible inventory **aws**  (same with ENV_ID) to use.

### AWS

```
.
├── cluster
├── maintenance.sh
├── master
├── setup.sh
├── setup_aws.sh   <--- Run this script.
└── setup_cluster.sh
```

### Hadoop + Spark
In the directory, run run_Spark.sh. If DATADOG_API_KEY is not set, the 51_datadog module will cause errors.

```
.
├── cluster
├── maintenance.sh
├── setup.sh
├── setup_aws.sh
└── setup_cluster.sh   <---- Run this script
```

Alternatively, run each module one by one, and skip 51_datadog if not using.
```
pushd ansible/Spark/<module>/scripts && ./main.sh or
ansible/Spark/<module>/scripts/main.sh aws <ansible remote_user>
```

Modules are:
```
├── 01_prerequisite      <---- Module to setup Ansible pre-requisites
├── 02_os                <---- Module to setup OS to install Spark
├── 03_packages          <---- Module to setup OS to install Spark
├── 20_hadoop            <---- Module to setup Spark cluster
├── 30_spark             <---- Module to setup Spark cluster
├── 40_application       <---- Module to run Spark applications
├── 50_datadog           <---- Module to setup datadog monitoring (option)
├── conductor.sh         <---- Script to conduct playbook executions
└── player.sh            <---- Playbook player
```


---

# Hadoop 

## configurations

### mapreduce-site.xml
```aidl
<configuration>
    <property>
      <name>mapreduce.framework.name</name>
      <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.map.memory.mb</name>
        <value>{{ YARN_MR_MAP_MEMORY_MB }}</value>
    </property>
    <property>
        <name>mapreduce.map.java.opts</name>
        <value>{{ YARN_MR_MAP_JAVA_OPTS }}</value>
    </property>
    <property>
        <name>mapreduce.reduce.memory.mb</name>
        <value>{{ YARN_MR_REDUCE_MEMORY_MB }}</value>
    </property>
    <property>
        <name>mapreduce.reduce.java.opts</name>
        <value>{{ YARN_MR_REDUCE_JAVA_OPTS }}</value>
    </property>

   <!--
  Without below, Error: Could not find or load main class org.apache.hadoop.mapreduce.v2.app.MRAppMaster .
  See https://stackoverflow.com/questions/50927577/could-not-find-or-load-main-class-org-apache-hadoop-mapreduce-v2-app-mrappmaster as well.
   -->
    <property>
      <name>yarn.app.mapreduce.am.env</name>
      <value>HADOOP_MAPRED_HOME={{ HADOOP_HOME }}</value>
    </property>
    <property>
      <name>mapreduce.map.env</name>
      <value>HADOOP_MAPRED_HOME={{ HADOOP_HOME }}</value>
    </property>
    <property>
      <name>mapreduce.reduce.env</name>
      <value>HADOOP_MAPRED_HOME={{ HADOOP_HOME }}</value>
    </property>

</configuration>

```

# Spark
## Configurations

Hadoop configuration files are required for Spark to access Hadoop/Yarn. Set the environment variables referring to the Hadoop/Yarn configuration directories.

* HADOOP_CONF_DIR
* YARN_CONF_DIR

