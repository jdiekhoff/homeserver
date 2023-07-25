#!/bin/bash

CERT_NAME=$1
parent_path=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

pushd "$parent_path"

mkdir ../certs

openssl req -new -sha256 -nodes -out ../certs/$CERT_NAME.csr -newkey rsa:2048 -keyout ../certs/$CERT_NAME.key -config <( cat ../config/certs/$CERT_NAME/server.csr.cnf )

openssl x509 -req -in ../certs/$CERT_NAME.csr -CA ~/ssl/rootCA.pem -CAkey ~/ssl/rootCA.key -CAcreateserial -out ../certs/$CERT_NAME.crt -days 500 -sha256 -extfile ../config/certs/$CERT_NAME/v3.ext

popd