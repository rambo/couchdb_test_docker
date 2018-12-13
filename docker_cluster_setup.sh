#!/bin/bash -x
docker network create couchdb_cluster
docker run -d --name cluster_couchdb1 --network couchdb_cluster -p 5984:5984 couchdb
docker run -d --name cluster_couchdb2 --network couchdb_cluster couchdb
docker run -d --name cluster_couchdb3 --network couchdb_cluster couchdb

NODES="cluster_couchdb1 cluster_couchdb2 cluster_couchdb3"
COORDNODE=cluster_couchdb1


ADMINPW=foobar
NEW_UUID=`python3 -c "import uuid;print(uuid.uuid4().hex)"`
ERL_COOKIE=`python3 -c "import uuid,base64;print(base64.urlsafe_b64encode(uuid.uuid4().bytes+uuid.uuid4().bytes).decode('ascii'))"`
HTTP_SECRET=`python3 -c "import uuid,base64;print(base64.urlsafe_b64encode(uuid.uuid4().bytes+uuid.uuid4().bytes).decode('ascii'))"`
for NODENAME in $NODES
do
  echo $NODENAME
  docker exec -it $NODENAME /bin/bash -c "while [ ! -e /opt/couchdb/etc/local.d/docker.ini ]; do sleep 1; done"
  docker exec -it $NODENAME /bin/sed -i.old -e "s/^uuid\s*=\s*.*/uuid = $NEW_UUID/" /opt/couchdb/etc/local.d/docker.ini
  docker exec -it $NODENAME rm /opt/couchdb/etc/local.d/docker.ini.old
  docker exec -it $NODENAME /bin/bash -c "echo '' >>/opt/couchdb/etc/vm.args; echo -name couchdb@$NODENAME >>/opt/couchdb/etc/vm.args; echo -setcookie $ERL_COOKIE >>/opt/couchdb/etc/vm.args"
  docker restart $NODENAME
  docker exec -it $NODENAME /bin/bash -c 'CHECK=1; while [ $CHECK -ne 0 ]; do curl http://127.0.0.1:5984/; CHECK=$?; sleep 1; done;'
  docker exec -it $NODENAME /usr/bin/curl -X PUT http://127.0.0.1:5984/_node/_local/_config/admins/admin -d '"'$ADMINPW'"'
  docker exec -it $NODENAME /usr/bin/curl -X PUT http://admin:$ADMINPW@127.0.0.1:5984/_node/_local/_config/couch_httpd_auth/secret -d '"'$HTTP_SECRET'"'

  docker exec -it $NODENAME /usr/bin/curl -X POST -H "Content-Type: application/json" http://admin:$ADMINPW@127.0.0.1:5984/_cluster_setup -d '{"action": "enable_cluster", "bind_address":"0.0.0.0", "username": "admin", "password":"'$ADMINPW'", "node_count":"3"}'
done

for NODENAME in $NODES
do
  for OTHERNODE in $( echo $NODES | sed -e "s/$NODENAME//")
  do
    docker exec -it $COORDNODE /usr/bin/curl -X POST -H "Content-Type: application/json" http://admin:$ADMINPW@127.0.0.1:5984/_cluster_setup -d '{"action": "enable_cluster", "bind_address":"0.0.0.0", "username": "admin", "password":"'$ADMINPW'", "port": 5984, "node_count": "3", "remote_node": "'$OTHERNODE'", "remote_current_user": "admin", "remote_current_password": "'$ADMINPW'" }'
    docker exec -it $COORDNODE /usr/bin/curl -X POST -H "Content-Type: application/json" http://admin:$ADMINPW@127.0.0.1:5984/_cluster_setup -d '{"action": "add_node", "host":"'$OTHERNODE'", "port": 5984, "username": "admin", "password":"'$ADMINPW'"}'
  done
  docker exec -it $COORDNODE /usr/bin/curl -X PUT http://admin:$ADMINPW@127.0.0.1:5986/_nodes/couchdb@$NODENAME -d '{}'
done

#for NODENAME in $NODES
#do
#  docker exec -it $NODENAME /usr/bin/curl -X POST -H "Content-Type: application/json" http://admin:$ADMINPW@127.0.0.1:5984/_cluster_setup -d '{"action": "finish_cluster"}'
#done
docker exec -it $COORDNODE /usr/bin/curl -X POST -H "Content-Type: application/json" http://admin:$ADMINPW@127.0.0.1:5984/_cluster_setup -d '{"action": "finish_cluster"}'

sleep 10

echo ""
echo "***************"
for NODENAME in $(echo "cluster_couchdb1 cluster_couchdb2 cluster_couchdb3")
do
  echo $NODENAME
  docker exec -it $NODENAME /usr/bin/curl http://admin:$ADMINPW@127.0.0.1:5984/_cluster_setup
  docker exec -it $NODENAME /usr/bin/curl http://admin:$ADMINPW@127.0.0.1:5984/_membership
done

set +x
echo ""
echo "***************"
echo "Admin credentials admin:$ADMINPW"
echo "go to http://admin:$ADMINPW@127.0.0.1:5984/_utils/ to finish cluster setup"
