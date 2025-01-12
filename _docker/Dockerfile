FROM python:3.10-slim-buster

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    rsync \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN curl -OL https://nodejs.org/dist/v18.16.1/node-v18.16.1-linux-x64.tar.xz && \
    tar xpfv node-v18.16.1-linux-x64.tar.xz && \
    mv node-v18.16.1-linux-x64 /node && \
    rm -f node-v18.16.1-linux-x64.tar.xz
ENV PATH "$PATH:/node/bin"

# for github.com ssh access
COPY dot.ssh/* /root/.ssh/

WORKDIR /scripts
COPY check-push.sh /scripts
COPY hook.py /scripts
COPY *.whl /scripts
RUN pip install /scripts/*.whl

CMD /scripts/hook.py
