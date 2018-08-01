# We cannot start from rixed/ramen:dev since it would prevent squashing
FROM debian:stable-slim

# Do not install recommends:
RUN echo 'APT::Install-Recommends "0";' > \
      /etc/apt/apt.conf.d/no_recommends

# Install a few things
RUN apt-get --yes update && \
    DEBIAN_FRONTEND=noninteractive \
      apt-get --yes install \
        gcc \
        libblas-dev \
        liblapack-dev \
        libsqlite3-0 \
        collectd \
        fprobe \
        util-linux \
        coreutils

# Rebuild a new image from here
RUN echo "version 1.4.0~0"

# Install ramen and configurator
COPY *.deb /tmp/
RUN dpkg -i /tmp/*.deb && rm /tmp/*.deb

# And the configuration used for alerting
COPY alert.conf /ramen/

# Environment
ENV RAMEN_PERSIST_DIR=/ramen

# cohttp/conduit requires /etc/protocols and /etc/services,
# which debian-slim does not provide:
COPY protocols services /etc/
COPY start /

# Command to be run:
WORKDIR /ramen
ENTRYPOINT ["/start"]

# Default arguments if not provided on `docker run` command line:
CMD ["--to-stderr"]

LABEL maintainer="rixed-docker@happyleptic.org"
