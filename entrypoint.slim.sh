#!/bin/bash

# Palworld Server Container Entrypoint (slim - sans SSH)
# Gère l'initialisation du conteneur, la sauvegarde et le démarrage du serveur

# Validation du répertoire de sauvegarde
if [ ! -d "$SAVE_DIR" ]; then
    echo "ERROR: SAVE_DIR '$SAVE_DIR' does not exist"
    exit 1
fi

# Gestionnaire d'arrêt propre du conteneur (SIGTERM / SIGINT)
shutdown() {
    echo "Container shutdown initiated..."
    echo "Stopping Palword server..."
    launch.sh stop
    echo "Shutdown completed."
    exit 0
}

# Initialisation du conteneur
setup() {
    # Gestion d'un APPLOCATION personnalisé via docker-compose
    if [ "${APPLOCATION}" != "/home/palword/PalwordGame" ]; then
        echo "APPLOCATION override detected: ${APPLOCATION}"
        mkdir -p "${APPLOCATION}"

        if [ ! -f "${APPLOCATION}/PalServer.sh" ]; then
            if [ -d "/home/palword/PalwordGame" ] && [ -f "/home/palword/PalwordGame/PalServer.sh" ]; then
                echo "Creating symlink from default installation to custom location..."
                ln -sf /home/palword/PalwordGame/* "${APPLOCATION}/"
            else
                echo "WARNING: No Palworld server installation found."
            fi
        fi

        if [ -f "/home/palword/PalwordGame/DefaultPalWorldSettings.ini" ] && [ ! -f "${APPLOCATION}/DefaultPalWorldSettings.ini" ]; then
            cp /home/palword/PalwordGame/DefaultPalWorldSettings.ini "${APPLOCATION}/DefaultPalWorldSettings.ini"
            chown palword:game-server "${APPLOCATION}/DefaultPalWorldSettings.ini"
        fi

        export SAVE_DIR="${APPLOCATION}/Pal/Saved"
        mkdir -p "${SAVE_DIR}"
        chown -R palword:game-server "${APPLOCATION}" "${SAVE_DIR}"
    fi
}

# Enregistrement des handlers de signaux
trap shutdown SIGTERM SIGINT

# Exécution de la configuration initiale
setup

# Démarrage du service cron pour les tâches planifiées
sudo service cron start
echo "Cron service started"

# Permissions sur les répertoires de sauvegarde et configuration
echo "Setting up directory permissions..."
chmod -R g+rw "$SAVE_DIR" "$CONFIG_DIR"

# Lancement du serveur Palworld
echo "Starting Palword server..."
launch.sh auto

# Maintien du conteneur actif en attendant les signaux
echo "Server started, container operational"
tail -f /dev/null &
wait $!
