FROM ubuntu:16.04

RUN apt-get update && apt-get build-dep synapse -y

COPY . /home/ubuntu/synapse
WORKDIR /home/ubuntu/synapse

RUN ./autogen.sh
RUN make
RUN make install
