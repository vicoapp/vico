#!/bin/sh

openssl ecparam -out ec-private-fake.pem -name secp192k1 -genkey
openssl ec -in ec-private-fake.pem -pubout -out ec-public-fake.pem

openssl ecparam -out ec-private.pem -name secp192k1 -genkey
openssl ec -in ec-private.pem -pubout -out ec-public.pem

openssl ec -in ec-private.pem -text -noout

