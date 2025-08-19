FROM python:3.12-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    rsync \
    curl \
    netcat-openbsd \
    xz-utils \
    nodejs  \
    npm  \
    && rm -rf /var/lib/apt/lists/*

# for github.com ssh access
COPY dot.ssh/* /root/.ssh/

WORKDIR /scripts
COPY check-push.sh /scripts
COPY hook.py /scripts
COPY *.whl /scripts
RUN pip install /scripts/*.whl

CMD /scripts/hook.py
