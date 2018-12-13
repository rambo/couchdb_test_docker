#!/bin/bash
if [ -z "${ADMINPW}" ]
then
  ADMINPW=foobar
fi
if [ -z "${COORDNODE}" ]
then
  COORDNODE=cluster_couchdb1
fi
TEST_CLIENT_NAMES="client1 client2"

echo " *** Create some test data ***"
docker exec -it $COORDNODE /usr/bin/curl -X PUT -H "Content-Type: application/json" http://admin:$ADMINPW@127.0.0.1:5984/vaplatformdata
for CLIENTID in $TEST_CLIENT_NAMES
do
  DOCID=`python3 -c "import uuid,base64;print(base64.urlsafe_b64encode(uuid.uuid4().bytes).decode('ascii'))"`
  TS=`python3 -c "import datetime; print(datetime.datetime.utcnow().isoformat()+'Z')"`
  docker exec -it $COORDNODE /usr/bin/curl -X POST -H "Content-Type: application/json" http://admin:$ADMINPW@127.0.0.1:5984/vaplatformdata -d '{"_id": "'$DOCID'", "clientid": "'$CLIENTID'", "time": "'$TS'"}'
done
