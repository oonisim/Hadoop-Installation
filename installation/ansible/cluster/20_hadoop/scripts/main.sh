#!/bin/bash
#--------------------------------------------------------------------------------
# Run the ansible playbook.
#--------------------------------------------------------------------------------
set -eu
DIR=$(realpath $(dirname $0))

#--------------------------------------------------------------------------------
# Environment variable requirements
#--------------------------------------------------------------------------------
export HADOOP_NN_HOSTNAME=${HADOOP_NN_HOSTNAME:?"Set HADOOP_NN_HOSTNAME"}
export YARN_RM_HOSTNAME=${YARN_RM_HOSTNAME:?"Set YARN_RM_HOSTNAME"}
export HADOOP_WORKERS=${HADOOP_WORKERS:?"Set HADOOP_WORKERS"}

#--------------------------------------------------------------------------------
# PLAYBOOK_DIR: ../plays as convention
# TARGET:       Target environment
# REMOTE_USER:  SSH user on the remote server
#--------------------------------------------------------------------------------
PLAYBOOK_DIR=$(realpath "$(dirname $0)/../plays")
if [ $# -ge 2 ]; then
    TARGET=$1
    REMOTE_USER=$2

    shift 2
    ARGS="$@"
else
    echo "Target inventory?"
    read TARGET

    echo "Remote user to use in the target servers?"
    read REMOTE_USER

    echo "args?"
    read ARGS
fi

. ${DIR}/_utility.sh
. ${DIR}/_pretask.sh
. ${DIR}/_python.sh

echo "#--------------------------------------------------------------------------------"
echo "# starting ansible playbook (it may take a while in case of EC2)..."
echo "#--------------------------------------------------------------------------------"

$(_locate ${DIR} '/' 'conductor.sh') \
  ${PLAYBOOK_DIR} \
  ${TARGET} \
  ${REMOTE_USER} \
  ${ARGS}

. ${DIR}/_posttask.sh
