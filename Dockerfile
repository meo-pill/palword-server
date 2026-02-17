# ARK: Survival Evolved Server Docker Image
# Production-ready ARK server with monitoring, backup, and SSH access
# Based on SteamCMD for official ARK server installation

######## BUILDER STAGE ########

# Use official SteamCMD image as base (Ubuntu-based with SteamCMD pre-installed)
FROM steamcmd/steamcmd:latest

# Labels for better Docker Hub integration
LABEL description="Palword dedicated server with monitoring, backup, and SSH access"
LABEL version="1.0.0"

# Environment variables for ARK server configuration
ENV USER=palword
ENV HOME=/home/palword
ENV CONFIG_DIR=/PalwordConfig
ENV APPLOCATION=/home/palword/PalwordGame
ENV SAVE_DIR=${APPLOCATION}/Pal/Saved
ENV APP_ID=2394010

# Configuration variables for monitoring and backup systems
ENV MAX_BACKUPS=24
ENV BACKUP_INTERVAL=3600

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Enable 32-bit architecture and install system prerequisites
# Includes ARK server dependencies, SSH server, and monitoring tools
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        screen \
        htop \
        nano \
        curl \
        wget \
        ca-certificates \
        software-properties-common \
        lib32gcc-s1 \
        lib32stdc++6 \
        libc6-i386 \
        libcurl4:i386 \
        libcurl4-gnutls-dev:i386 \
        openssh-server \
        net-tools \
        procps \
        tzdata \
        iputils-ping \
        cron \
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/* \
    && rm -rf /var/log/* \
    && truncate -s 0 /var/log/*log

# Setup SSH service configuration
RUN mkdir -p /var/run/sshd

# Create user for proper file permissions BEFORE steamcmd
# game-server (GID 5000): Main group for Palword server files
# developer (GID 4000): Development access group
RUN groupadd -g 5000 game-server \
    && groupadd -g 4000 developer \
    && useradd -u 3009 -g game-server -G developer -m -s /bin/bash palword \
    && echo "palword:password" | chpasswd \
    && apt-get update && apt-get install -y sudo \
    && usermod -aG sudo palword \
    && echo "palword ALL=(ALL) NOPASSWD: /etc/init.d/ssh" >> /etc/sudoers.d/palword \
    && chmod 0440 /etc/sudoers.d/palword \
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* \
    && mkdir -p ${APPLOCATION} \
    && chown -R palword:game-server /home/palword

# Set working directory
WORKDIR $HOME

# Switch to palword user as default
USER palword

# Download and install Palword server as root, then fix permissions
# App ID 2394010 is the official Palword dedicated server
RUN steamcmd +force_install_dir ${APPLOCATION} +login anonymous +app_update ${APP_ID} validate +quit

# switch back to root for final configuration and cleanup
USER root

# Declare persistent volumes for external data storage
VOLUME ["${CONFIG_DIR}", "${SAVE_DIR}"]

# Configure system PATH for Palword server binaries
ENV PATH="/home/palword/PalwordGame${PATH}"
ENV PATH="${HOME}:${PATH}"

# Create necessary directories with proper permissions
RUN mkdir -p ${CONFIG_DIR} ${SAVE_DIR} \
    && chown -R palword:game-server ${CONFIG_DIR} ${SAVE_DIR} \
    && chmod -R 775 ${CONFIG_DIR}

# Copy default Palworld configuration file to installation root
COPY --chown=palword:game-server ./config/DefaultPalWorldSettings.ini ${APPLOCATION}/DefaultPalWorldSettings.ini

# Copy configuration files and application scripts
# SSH configuration for secure remote access
COPY --chown=root:root ./config/sshd_config /etc/ssh/sshd_config
# Application scripts: server management, health monitoring, backup management, and startup
COPY --chown=palword:game-server ./app/launch.sh ./entrypoint.sh ./healthcheck.sh /home/palword/

# Set executable permissions for all application scripts
RUN chmod +x /home/palword/launch.sh \
    && chmod +x /home/palword/entrypoint.sh \
    && chmod +x /home/palword/healthcheck.sh \
    && chmod 644 /etc/ssh/sshd_config

# Add cron job to restart the server daily at 14:00
RUN (echo "0 14 * * * /home/palword/launch.sh restart") | crontab -u palword - \
    && crontab -l -u palword;

# Configure shell environment with useful aliases and environment variables
# Create convenient aliases for navigation and set persistent environment variables
RUN echo "alias conf='cd ${CONFIG_DIR}'" >> /home/palword/.bashrc \
    && echo 'alias save="cd ${SAVE_DIR}"' >> /home/palword/.bashrc \
    && echo 'export CONFIG_DIR=/PalwordConfig' >> /home/palword/.bashrc \
    && echo 'export APPLOCATION=/home/palword/PalwordGame' >> /home/palword/.bashrc \
    && echo 'export SAVE_DIR=${APPLOCATION}/Pal/Saved' >> /home/palword/.bashrc \
    && echo 'PATH="/home/palword/PalwordGame:${PATH}"' >> /home/palword/.bashrc \
    && echo 'PATH="${HOME}:${PATH}"' >> /home/palword/.bashrc \
    && echo 'export PATH' >> /home/palword/.bashrc

# Expose network ports for Palworld server services
# Palworld game connection ports (supports multiple server instances)
EXPOSE 8211
# Steam query ports for server discovery and status
# Range 27015-27019 are default Steam ports
EXPOSE 27015
# SSH access port for remote administration
EXPOSE 22

# Switch to palword user as default
USER palword

# Set working directory to configuration mount point
WORKDIR ${CONFIG_DIR}

# Configure container startup and health monitoring
ENTRYPOINT [ "/home/palword/entrypoint.sh" ]

# Health check configuration for container orchestration
# Checks server status every minute with 30-second timeout
# Allows 5-minute startup period with up to 3 retries before marking unhealthy
HEALTHCHECK --interval=1m --timeout=30s --start-period=5m --retries=3 \
    CMD ["/home/palword/healthcheck.sh"] || exit 1