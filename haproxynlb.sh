#!/bin/bash

# Vérification des droits root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant qu'utilisateur root."
    exit 1
fi

echo "Mise à jour du système et installation de HAProxy..."
sudo apt-get update -y
sudo apt-get install haproxy -y

echo "Combien de serveurs web souhaitez-vous configurer dans le backend ?"
read -p "Nombre de serveurs : " server_count

# Vérification que le nombre est valide
if ! [[ "$server_count" =~ ^[0-9]+$ ]] || [ "$server_count" -le 0 ]; then
    echo "Veuillez entrer un nombre entier positif."
    exit 1
fi

# Demande des IP des serveurs
declare -a server_ips
for (( i=1; i<=server_count; i++ )); do
    read -p "Entrez l'adresse IP du serveur $i : " ip
    server_ips+=("$ip")
done

# Chemin du fichier de configuration
haproxy_cfg="/etc/haproxy/haproxy.cfg"

# Sauvegarde de l'ancien fichier de configuration
echo "Sauvegarde de la configuration actuelle..."
cp "$haproxy_cfg" "${haproxy_cfg}.bak"

# Génération de la nouvelle configuration
echo "Génération de la nouvelle configuration..."

cat <<EOL > "$haproxy_cfg"
# Configuration HAProxy générée automatiquement

# Section globale
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

# Réglages par défaut
defaults
    log     global
    option  httplog
    option  dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

# Définition du frontend
frontend http_cluster
    bind *:80
    default_backend serveurs_http

# Définition du backend
backend serveurs_http
    balance roundrobin
    option httpchk
EOL

# Ajout des serveurs dans la configuration backend
for (( i=0; i<server_count; i++ )); do
    server_number=$((i + 1))
    echo "    server web$server_number ${server_ips[$i]}:80 check" >> "$haproxy_cfg"
done

echo "Configuration générée avec succès dans $haproxy_cfg."

# Redémarrage de HAProxy
echo "Redémarrage de HAProxy..."
sudo systemctl restart haproxy

echo "HAProxy a été configuré et redémarré avec succès !"
echo "Les serveurs suivants ont été ajoutés :"
for ip in "${server_ips[@]}"; do
    echo "- $ip"
done
