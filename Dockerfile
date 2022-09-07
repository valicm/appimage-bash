# Base image
FROM alpine:latest

# installes required packages for our script
RUN	apk add --no-cache \
  bash \
  ca-certificates \
  curl \
  jq \
  convert

# Copies your code file  repository to the filesystem
COPY build.sh /build.sh

# change permission to execute the script and
RUN chmod +x /build.sh

# file to execute when the docker container starts up
ENTRYPOINT ["/build.sh"]
