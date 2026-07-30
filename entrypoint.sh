#!/bin/bash
# Palworld Server Container Entrypoint
# Le serveur tourne en foreground comme processus principal du conteneur.
# Utilisez 'docker logs' pour voir les logs, 'docker exec' pour accéder au conteneur.

# Vérifier et créer les répertoires nécessaires
mkdir -p "$SAVE_DIR" "$CONFIG_DIR"

# Vérifier que le binaire serveur existe et est exécutable
if [ ! -x "${APPLOCATION}/PalServer.sh" ]; then
    echo "ERROR: PalServer.sh introuvable ou non exécutable : ${APPLOCATION}/PalServer.sh"
    exit 1
fi

# Si il n'existe pas de fichier de configuration, copier le fichier par défaut
if [ ! -f "${CONFIG_DIR}/PalWorldSettings.ini" ]; then
    echo "Fichier de configuration introuvable, copie du fichier par défaut..."
    cp "${APPLOCATION}/DefaultPalWorldSettings.ini" "${CONFIG_DIR}/PalWorldSettings.ini"
    cp "${APPLOCATION}/DefaultPalWorldSettings.ini" "${CONFIG_DIR}/DefaultPalWorldSettings.ini"
fi

# On écrase le ficher de configuration de la sauvegarde avec celui du dossier de configuration
if [ -f "${CONFIG_DIR}/PalWorldSettings.ini" ]; then
    echo "Copie du fichier de configuration dans le dossier de sauvegarde..."
    cp "${CONFIG_DIR}/PalWorldSettings.ini" "${SAVE_DIR}/Config/LinuxServer/PalWorldSettings.ini"
fi

# Transférer le signal SIGTERM de Docker vers le processus serveur pour un arrêt propre
_shutdown() {
    echo "Signal d'arrêt reçu, arrêt du serveur Palworld..."
    kill -TERM "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
    echo "Serveur arrêté."
    exit 0
}
trap _shutdown SIGTERM SIGINT

echo "Démarrage du serveur dédié Palworld..."
echo "  Config : $CONFIG_DIR"
echo "  Saves  : $SAVE_DIR"
echo "  App    : $APPLOCATION"
echo "  Nom    : ${SERVER_NAME}"
echo "  Port   : ${SERVER_PORT}"
echo "  Joueurs: ${PLAYERS}"

# Construire la commande de lancement à partir des variables d'environnement
LAUNCH_ARGS=(
    "-port=${SERVER_PORT}"
    "-players=${PLAYERS}"
    "-NumberOfWorkerThreadsServer=8"
)

[ -n "$SERVER_NAME" ]     && LAUNCH_ARGS+=("-ServerName=${SERVER_NAME}")
[ -n "$SERVER_PASSWORD" ] && LAUNCH_ARGS+=("-ServerPassword=${SERVER_PASSWORD}")
[ -n "$ADMIN_PASSWORD" ]  && LAUNCH_ARGS+=("-AdminPassword=${ADMIN_PASSWORD}")
[ -n "$PUBLIC_IP" ]       && LAUNCH_ARGS+=("-PublicIP=${PUBLIC_IP}")
[ "$COMMUNITY" = "true" ] && LAUNCH_ARGS+=("-publiclobby")

# Lancer le serveur — les logs vont directement vers Docker (stdout/stderr)
"${APPLOCATION}/PalServer.sh" "${LAUNCH_ARGS[@]}" &

SERVER_PID=$!
echo "Serveur démarré (PID $SERVER_PID)"

# Attendre la fin du processus serveur (maintient le conteneur en vie)
wait $SERVER_PID
