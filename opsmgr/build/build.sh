#!/bin/bash

SCRIPT_PATH="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"
cd $SCRIPT_PATH # make sure we're in the right directory

./build-logstash.sh
./build-elasticsearch.sh
./build-kibana.sh
./build-beats.sh

