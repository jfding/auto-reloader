FROM python:3.6-slim-stretch

RUN apt-get update && \
    apt-get install -y \
    git \
    rsync \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /scripts
COPY monit.sh /scripts

# for github.com ssh access
COPY dot.ssh/* /root/.ssh/

CMD /scripts/monit.sh
