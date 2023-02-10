ARG  NIM_VERSION=1.4.0
FROM nimlang/nim:${NIM_VERSION}
RUN  apt-get update && apt-get install -y sqlite3 postgresql-client
RUN  nim -v