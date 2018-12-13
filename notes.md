# setup test images

run `docker_cluster_setup.sh`


#docker exec -it cluster_couchdb1 'curl http://127.0.0.1:5986/'


Fauxton: http://127.0.0.1:5984/_utils/


docker run -d --name client1_couchdb -p 5984:5985 couchdb
docker run -d --name client2_couchdb -p 5984:5986 couchdb
