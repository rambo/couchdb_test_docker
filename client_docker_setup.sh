#!/bin/bash
if [ -z "${CLIENTNAME}" ]
then
  echo "CLIENTNAME must be defined"
  exit 1
fi
if [ -z "${CLUSTERADMINPW}" ]
then
  echo "CLUSTERADMINPW must be defined"
  exit 1
fi
if [ -z "${CLIENTPORT}" ]
then
  echo "CLIENTPORT must be defined"
  exit 1
fi
if [ -z "${CLIENTADMINPW}" ]
then
  CLIENTADMINPW=barfoo
fi
if [ -z "${CLUSTERCOORDNODE}" ]
then
  CLUSTERCOORDNODE=cluster_couchdb1
fi

CLUSTERCOORDNODEIP=`docker inspect -f '{{.NetworkSettings.Networks.fake_internet.IPAddress}}' $CLUSTERCOORDNODE`


CLIENTDB="${CLIENTNAME}_vaplatformdata"
NODENAME="${CLIENTNAME}_couchdb"
CLIENTUSER="${CLIENTNAME}_replicator"
HTTP_SECRET=`python3 -c "import uuid,base64;print(base64.urlsafe_b64encode(uuid.uuid4().bytes+uuid.uuid4().bytes).decode('ascii'))"`
REPLICATORPW=`python3 -c "import uuid,base64;print(base64.urlsafe_b64encode(uuid.uuid4().bytes+uuid.uuid4().bytes).decode('ascii'))"`

echo "*** Creating and waiting for the docker container ***"
docker run -d --name $NODENAME --network fake_internet -p $CLIENTPORT:5984 couchdb
docker exec -it $NODENAME /bin/bash -c 'CHECK=1; while [ $CHECK -ne 0 ]; do curl http://127.0.0.1:5984/; CHECK=$?; sleep 1; done;'
echo "*** Configuring passwords and finishing single-node cluster installation ***"
docker exec -it $NODENAME /usr/bin/curl -X PUT http://127.0.0.1:5984/_node/_local/_config/admins/admin -d '"'$CLIENTADMINPW'"'
docker exec -it $NODENAME /usr/bin/curl -X PUT http://admin:$CLIENTADMINPW@127.0.0.1:5984/_node/_local/_config/couch_httpd_auth/secret -d '"'$HTTP_SECRET'"'
docker exec -it $NODENAME /usr/bin/curl -X PUT http://admin:$CLIENTADMINPW@127.0.0.1:5984/_node/_local/_config/admins/replicator -d '"'$REPLICATORPW'"'
docker exec -it $NODENAME /usr/bin/curl -X POST -H "Content-Type: application/json" http://admin:$CLIENTADMINPW@127.0.0.1:5984/_cluster_setup -d '{"action": "finish_cluster"}'

echo "*** Creating replication user and documents ****"
docker exec -it $CLUSTERCOORDNODE /usr/bin/curl -X PUT -H "Content-Type: application/json" http://admin:$CLUSTERADMINPW@127.0.0.1:5984/$CLIENTDB
docker exec -it $CLUSTERCOORDNODE /usr/bin/curl -X PUT http://admin:$CLUSTERADMINPW@127.0.0.1:5984/_users/org.couchdb.user:$CLIENTUSER -H "Content-Type: application/json" -d '{"name": "'$CLIENTUSER'", "password": "'$REPLICATORPW'", "roles": [], "type": "user"}'
# TODO automate adding of the replicator user as member to the table

NODEIP=`docker inspect -f '{{.NetworkSettings.Networks.fake_internet.IPAddress}}' $NODENAME`
docker exec -it $NODENAME /usr/bin/curl -X PUT -H "Content-Type: application/json" http://admin:$CLIENTADMINPW@127.0.0.1:5984/vaplatformdata
sleep 5 # TODO: smarter wait for the db to be created
docker exec -it $NODENAME /usr/bin/curl -X POST http://admin:$CLIENTADMINPW@127.0.0.1:5984/_replicator -H "Content-Type: application/json" -d '{ "_id": "'$CLIENTNAME'_vaplatform_downstream", "source": "http://'$CLIENTUSER':'$REPLICATORPW'@'$CLUSTERCOORDNODEIP':5984/'$CLIENTDB'", "target": "http://replicator:'$REPLICATORPW'@127.0.0.1:5984/vaplatformdata", "selector": { "clientid": "'$CLIENTNAME'" }, "continuous":  true}'
docker exec -it $NODENAME /usr/bin/curl -X POST http://admin:$CLIENTADMINPW@127.0.0.1:5984/_replicator -H "Content-Type: application/json" -d '{ "_id": "'$CLIENTNAME'_vaplatform_upstream", "source": "http://replicator:'$REPLICATORPW'@127.0.0.1:5984/vaplatformdata", "target": "http://'$CLIENTUSER':'$REPLICATORPW'@'$CLUSTERCOORDNODEIP':5984/'$CLIENTDB'", "selector": { "clientid": "'$CLIENTNAME'" }, "continuous":  true}'

echo "*** Creating test document ****"
DOCID=`python3 -c "import uuid,base64;print(base64.urlsafe_b64encode(uuid.uuid4().bytes).decode('ascii'))"`
TS=`python3 -c "import datetime; print(datetime.datetime.utcnow().isoformat()+'Z')"`
docker exec -it $NODENAME /usr/bin/curl -X POST -H "Content-Type: application/json" http://admin:$CLIENTADMINPW@127.0.0.1:5984/vaplatformdata -d '{"_id": "'$DOCID'", "clientid": "'$CLIENTNAME'", "time": "'$TS'", "extra": "created by client local setup script"}'

echo "*********** DONE **********''"
echo "*** ACTION: On the cluster add user $CLIENTUSER as member to vaplatformdata"
echo "*** $NODENAME admin pw is $CLIENTADMINPW replicator pw is $REPLICATORPW ***"
