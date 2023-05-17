#!/bin/bash
openssl req -nodes -new -x509 -days 365 -newkey rsa:4096 -keyout "../certs/$1.key" -out "../certs/$1.crt"