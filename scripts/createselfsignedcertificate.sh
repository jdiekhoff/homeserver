#!/bin/bash

CERT_NAME=$1
parent_path=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

pushd "$parent_path"

mkdir ../certificates

# Create CSR with new private key
# openssl req -new -sha256 -nodes -out ../certificates/$CERT_NAME/$CERT_NAME.csr -newkey rsa:2048 -keyout ../certificates/$CERT_NAME/$CERT_NAME.key -config <( cat ../certificates/$CERT_NAME/config/server.csr.cnf )

# Create CSR with existing private key
openssl req -new -sha256 -nodes -out ../certificates/$CERT_NAME/$CERT_NAME.csr -key ../certificates/$CERT_NAME/$CERT_NAME.key -config <( cat ../certificates/$CERT_NAME/config/server.csr.cnf )

# Sign CSR and output certificate
# TODO: Review the serial: https://stackoverflow.com/questions/66357451/why-does-signing-a-certificate-require-cacreateserial-argument
openssl x509 -req -in ../certificates/$CERT_NAME/$CERT_NAME.csr -CA ../ca/rootCA.pem -CAkey ../ca/rootCA.key -CAcreateserial -out ../certificates/$CERT_NAME/$CERT_NAME.crt -days 395 -sha256 -extfile ../certificates/$CERT_NAME/config/v3.ext

# Remove CSR
rm ../certificates/$CERT_NAME/$CERT_NAME.csr

popd