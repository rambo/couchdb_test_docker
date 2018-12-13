#!/bin/bash -x
CLIENT_NAMES="client1 client2"
if [ -z "${CLUSTERCOORDNODE}" ]
then
  CLUSTERCOORDNODE=cluster_couchdb1
fi
for CLIENTNAME in $CLIENT_NAMES
do
  if [ "${CLUSTERADMINPW}" != "" ]
  then
    CLIENTUSER="${CLIENTNAME}_replicator"
    docker exec -it $CLUSTERCOORDNODE /usr/bin/curl -X PUT http://admin:$CLUSTERADMINPW@127.0.0.1:5984/_users/org.couchdb.user:$CLIENTUSER -H "Content-Type: application/json"  -d  '{"name": "'$CLIENTUSER'", "_deleted": true}'
  fi
  NODENAME="${CLIENTNAME}_couchdb"
  docker stop $NODENAME
  docker rm $NODENAME
done
