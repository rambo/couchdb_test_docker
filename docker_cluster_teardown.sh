#!/bin/bash -x
./teardown_clients.sh
docker stop cluster_couchdb1 cluster_couchdb2 cluster_couchdb3
docker rm cluster_couchdb1 cluster_couchdb2 cluster_couchdb3
docker network remove couchdb_cluster
docker network remove fake_internet
