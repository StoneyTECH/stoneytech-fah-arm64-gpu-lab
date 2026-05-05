FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      fakeroot \
      git \
      libbz2-dev \
      liblz4-dev \
      libssl-dev \
      libsystemd-dev \
      npm \
      python3 \
      python3-pip \
      python3-venv \
      scons \
      zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace/stoneytech-fah-arm64-gpu-lab

CMD ["/bin/bash"]
