FROM nimlang/nim:1.0.0

WORKDIR /usr/src/app

COPY . /usr/src/app

RUN apt-get update && apt-get install -y sqlite3 postgresql-client
