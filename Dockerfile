# Base image
FROM ubuntu:20.04

RUN apt-get update
# installes required packages for our script
RUN	apt-get -y install \
  bash \
  ca-certificates \
  curl \
  jq \
  imagemagick \
  wget \
  fuse \
  libfuse2

RUN modprobe fuse
RUN groupadd fuse
RUN usermod -a -G fuse $(whoami)

# Copies your code file  repository to the filesystem
COPY build.sh /build.sh

# change permission to execute the script and
RUN chmod +x /build.sh

# file to execute when the docker container starts up
ENTRYPOINT ["/build.sh"]
