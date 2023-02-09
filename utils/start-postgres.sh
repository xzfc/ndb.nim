#!/bin/sh

exec docker run \
	--name lowdb-pg \
	-p 127.0.0.1:5432:5432 \
	-t -i --rm \
	-e POSTGRES_PASSWORD=postgres \
	postgres:11
