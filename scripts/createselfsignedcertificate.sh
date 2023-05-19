#!/bin/bash

parent_path=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

pushd "$parent_path"

mkdir ../certs

openssl req -new -sha256 -nodes -out ../certs/server.csr -newkey rsa:2048 -keyout ../certs/server.key -config <( cat ../config/certs/server.csr.cnf )

openssl x509 -req -in ../certs/server.csr -CA ~/ssl/rootCA.pem -CAkey ~/ssl/rootCA.key -CAcreateserial -out ../certs/server.crt -days 500 -sha256 -extfile ../config/certs/v3.ext

popd