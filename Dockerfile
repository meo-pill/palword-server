# Palworld Dedicated Server Docker Image
# Serveur Palworld dédié basé sur SteamCMD

# Use official SteamCMD image as base (Ubuntu-based with SteamCMD pre-installed)
FROM steamcmd/steamcmd:latest

# Labels for better Docker Hub integration
LABEL description="palworld dedicated server"
LABEL version="1.0.0"

# Variables d'environnement du serveur Palworld
ENV USER=palworld
ENV HOME=/home/palworld
ENV CONFIG_DIR=/palworldConfig
ENV APPLOCATION=/home/palworld/palworldGame
ENV SAVE_DIR=${APPLOCATION}/Pal/Saved
ENV APP_ID=2394010

# Configuration du serveur Palworld (surchargegable dans docker-compose.yml)
ENV SERVER_NAME="Palworld Server"
ENV PUBLIC_IP=""
ENV SERVER_PORT=8211
ENV PLAYERS=16
ENV COMMUNITY=false
# SERVER_PASSWORD et ADMIN_PASSWORD sont injectés au runtime via docker-compose (fichier .env)

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Enable 32-bit architecture and install system prerequisites
# Includes Palworld server dependencies and monitoring tools
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        lib32gcc-s1=16-20260322-1ubuntu1 \
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/* \
    && rm -rf /var/log/* \
    && truncate -s 0 /var/log/*log

# Create user for proper file permissions BEFORE steamcmd
# game-server (GID 5000): groupe principal des fichiers serveur
RUN groupadd -g 5000 game-server \
    && groupadd -g 4000 developer \
    && useradd --no-log-init -u 3009 -g game-server -G developer -m -s /bin/bash palworld \
    && mkdir -p ${APPLOCATION} \
    && chown -R palworld:game-server /home/palworld

# Set working directory
WORKDIR $HOME

# Switch to palworld user as default
USER palworld

# Téléchargement et installation du serveur Palworld via SteamCMD
# App ID 2394010 = serveur dédié Palworld officiel
RUN steamcmd +force_install_dir ${APPLOCATION} +login anonymous +app_update ${APP_ID} validate +quit

# switch back to root for final configuration and cleanup
USER root

# Declare persistent volumes for external data storage
VOLUME ["${CONFIG_DIR}", "${SAVE_DIR}"]

# Configure system PATH for palworld server binaries
ENV PATH="/home/palworld/palworldGame${PATH}"
ENV PATH="${HOME}:${PATH}"

# Create necessary directories with proper permissions
RUN mkdir -p ${CONFIG_DIR} ${SAVE_DIR} \
    && chown -R palworld:game-server ${CONFIG_DIR} ${SAVE_DIR} \
    && chmod -R 775 ${CONFIG_DIR}

# Copy default Palworld configuration file to installation root
COPY --chown=palworld:game-server ./config/DefaultPalWorldSettings.ini ${APPLOCATION}/DefaultPalWorldSettings.ini

# Application scripts: server management, health monitoring, and startup
COPY --chown=palworld:game-server ./entrypoint.sh ./healthcheck.sh /home/palworld/

# Set executable permissions for all application scripts
RUN chmod +x /home/palworld/entrypoint.sh \
    && chmod +x /home/palworld/healthcheck.sh

# Configure shell environment - variables persistantes pour docker exec
RUN echo 'export CONFIG_DIR=/palworldConfig' >> /home/palworld/.bashrc \
    && echo 'export APPLOCATION=/home/palworld/palworldGame' >> /home/palworld/.bashrc \
    && echo 'export SAVE_DIR=${APPLOCATION}/Pal/Saved' >> /home/palworld/.bashrc \
    && echo 'PATH="/home/palworld/palworldGame:${PATH}"' >> /home/palworld/.bashrc \
    && echo 'export PATH' >> /home/palworld/.bashrc

# Expose network ports for Palworld server services
# Palworld game connection port
EXPOSE 8211
# Steam query port for server discovery and status
EXPOSE 27015

# Switch to palworld user as default
USER palworld

# Set working directory to configuration mount point
WORKDIR ${CONFIG_DIR}

# Configure container startup and health monitoring
ENTRYPOINT [ "/home/palworld/entrypoint.sh" ]

# Health check configuration for container orchestration
# Checks server status every minute with 30-second timeout
# Allows 5-minute startup period with up to 3 retries before marking unhealthy
HEALTHCHECK --interval=1m --timeout=30s --start-period=5m --retries=3 \
    CMD ["/home/palworld/healthcheck.sh"] || exit 1