#!/bin/bash

while getopts d:n:b: option
do
case "${option}"
in
d) DOMAIN=${OPTARG};;#senza il www
n) APPNAME=${OPTARG};;
b) DBNAME = ${OPTARG};;
esac
done

if [ ! -z "$DBNAME" ]
  then
    DBNAME = $APPNAME
fi
echo "DBNAME is set to $DBNAME"
echo "APPNAME is set to $APPNAME"
echo "DOMAIN is set to $DOMAIN"
