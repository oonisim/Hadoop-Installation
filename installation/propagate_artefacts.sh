#!/usr/bin/env bash
if [ ! -n "${DIR+1}" ] ; then 
    DIR=$(realpath $(dirname .))
fi
. ${DIR}/_propagate_os_artefacts.sh
. ${DIR}/_propagate_hadoop_artefacts.sh
