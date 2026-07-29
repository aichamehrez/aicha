# ==============================================================================
#  OpenClaw — Custom Production Dockerfile
#  Build Strategy: Single-stage optimized image on official OpenClaw base
#  Adds baked tooling: sshpass, openssh-client, curl, nmap, netcat for VM reach
# ==============================================================================

FROM ghcr.io/openclaw/openclaw:latest

USER root

# Prevents interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies needed for VM communication, SSH execution, and diagnostics
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    sshpass \
    sshfs \
    fuse3 \
    curl \
    wget \
    netcat-openbsd \
    nmap \
    iputils-ping \
    dnsutils \
    iproute2 \
    net-tools \
    ca-certificates \
    openssl \
    git \
    jq \
    unzip \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Pre-create directory layout for the node user
RUN mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace && \
    chown -R node:node /home/node/.openclaw

# Create SSH directory with strict permissions (OpenSSH requirement)
RUN mkdir -p /home/node/.ssh && \
    chmod 700 /home/node/.ssh && \
    chown -R node:node /home/node/.ssh

# Disable strict host key checking inside the container (agent will connect to target VM)
RUN printf "Host *\n\
    StrictHostKeyChecking no\n\
    UserKnownHostsFile /dev/null\n\
    LogLevel ERROR\n\
    ServerAliveInterval 30\n\
    ServerAliveCountMax 3\n" > /home/node/.ssh/config && \
    chmod 600 /home/node/.ssh/config && \
    chown node:node /home/node/.ssh/config

# Switch to the non-root node user (UID 1000) for security
USER node

# Expose Web UI / Gateway port
EXPOSE 18789
