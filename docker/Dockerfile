# We cannot start from rixed/ramen:dev since it would prevent squashing
FROM localhost:5000/ramen

# Install ramen and configurator
COPY *.deb /tmp/
RUN dpkg -i /tmp/*.deb && rm /tmp/*.deb

# Command to be run:
WORKDIR /ramen
COPY start-dh /
ENTRYPOINT ["/start-dh"]

LABEL maintainer="ccellier@accedian.com"
