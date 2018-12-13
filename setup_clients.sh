#!/bin/bash -x
CLIENTNAME=client1 CLUSTERADMINPW=foobar CLIENTPORT=4984 ./client_docker_setup.sh
CLIENTNAME=client2 CLUSTERADMINPW=foobar CLIENTPORT=3984 ./client_docker_setup.sh
