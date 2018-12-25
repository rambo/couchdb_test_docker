# CouchDB replication tests

One 3 node "master" cluster, two "client local instances" and 2-way replication with the "master".

## Setup test images

run `docker_cluster_setup.sh`
run `create_test_data.sh`

Fauxton: <http://127.0.0.1:5984/_utils/>


run `setup_clients.sh`

Fauxtons: <http://127.0.0.1:4984/_utils/> <http://127.0.0.1:3984/_utils/>

## Testing

Note the replication filter when wondering why your newly created documents are not replicating.