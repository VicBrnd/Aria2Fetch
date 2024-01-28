#!/bin/bash

# Aria2Fetch Script
echo -ne "\033]0;Aria2Fetch 🚀\007"

# --- Initialisation des Variables Globales ---
# Dossiers et fichiers de configuration pour le script.
config_dir="$HOME/Documents/.Aria2Fetch"  # Dossier pour les fichiers de configuration et logs.
config_file="$config_dir/Config.cfg"      # Fichier de configuration pour stocker les chemins des répertoires.
logfile="$config_dir/aria2fetch.log"      # Fichier log pour enregistrer les activités du script.

# Codes de couleurs pour l'affichage dans le terminal.
RED='\033[0;31m'    # Rouge pour les messages d'erreur.
GREEN='\033[0;32m'  # Vert pour les messages de succès.
YELLOW='\033[1;33m' # Jaune pour les avertissements et les prompts.
BLUE='\033[0;34m'   # Bleu pour les titres et les options de menu.
MAGENTA='\033[0;35m' # Magenta pour les sous-titres.
CYAN='\033[0;36m'   # Cyan pour les informations complémentaires.
NC='\033[0m'        # 'No Color' pour réinitialiser la couleur.

# Icônes pour améliorer la visibilité des messages.
ICON_SUCCESS="✅"; ICON_FAIL="❌"; ICON_INFO="ℹ️"; ICON_QUESTION="❓"; ICON_WARNING="⚠️"

# Variables pour le rapport de téléchargement.
telechargements_reussis=0  # Compteur pour les téléchargements réussis.
telechargements_echoues=0  # Compteur pour les téléchargements échoués.
rapport=""  # String accumulant les rapports de chaque téléchargement.

# Variables pour les répertoires.
clear

# Création du dossier de configuration et du fichier log si non existants.
mkdir -p "$config_dir"
touch "$logfile"

# --- FONCTIONS D'UTILITAIRES ET D'AFFICHAGE ---
# Fonctions d'affichage dynamique.
print_message() {
    local color=$1
    local icon=$2
    local message=$3
    echo -e "${color}${icon} ${message}${NC}"
}
# Fonction pour logger les activités.
log_activity() {
    echo "[$(date)] $1" >> "$logfile"
}

# --- FONCTIONS DE VERIFICATION ET D'INSTALLATION DES DEPENDANCES ---
# Fonction pour demander à l'utilisateur d'installer des dépendances manquantes.
verifier_et_installer() {
    local logiciel=$1
    local commande_verification=$2
    local commande_installation=$3

    if ! command -v "$commande_verification" &> /dev/null; then
    printf "${ICON_WARNING}  ${YELLOW}$logiciel${NC} n'est pas installé. ❓ Voulez-vous l'installer ? ${YELLOW}Oui/Non${NC}. ${NC}\n"
    while true; do
        read -r reponse
        reponse=$(echo "$reponse" | tr '[:upper:]' '[:lower:]')
        case "$reponse" in
            oui|o|yes|y)
                printf "Installation de ${YELLOW}$logiciel${NC} en cours... ${ICON_INFO}\n"
                eval "$commande_installation" >/dev/null 2>&1
                printf "${YELLOW}$logiciel${NC} a été installé avec succès. ${ICON_SUCCESS}\n"
                break
                ;;
            non|n|no)
                printf "${RED}Installation annulée. ${YELLOW}$logiciel${NC} est nécessaire pour continuer. ${ICON_FAIL}${NC}\n"
                exit 1
                ;;
            *)
                printf "${RED}Réponse invalide. ${ICON_WARNING}${NC}\n"
                ;;
        esac
    done
fi
}
# Vérifier et installer les dépendances nécessaires
verifier_et_installer "Homebrew" "brew" "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
verifier_et_installer "Aria2" "aria2c" "brew install aria2"
verifier_et_installer "Zenity" "zenity" "brew install zenity"

# vérifier mise à jour du script
verifier_mise_a_jour() {
    local repo_url="https://github.com/VicBrnd/Aria2Fetch.git"
    local script_dir=$(cd "$(dirname "$0")" && pwd)
    local config_file="$HOME/Documents/.Aria2Fetch/Config.cfg"
    local current_version=$(git -C "$script_dir" describe --tags --abbrev=0)
    local latest_version=$(git ls-remote --tags "$repo_url" | cut -d'/' -f3 | sort -V | tail -n1)

    echo "Version actuelle: $current_version"
    echo "Vérification des mises à jour..."

    if [ "$latest_version" != "$current_version" ]; then
        echo "Nouvelle version disponible: $latest_version"
        echo "Voulez-vous mettre à jour le script ? (oui/non)"
        read -r reponse
        if [[ "$reponse" == "oui" ]]; then
            git -C "$script_dir" fetch --tags
            git -C "$script_dir" checkout "$latest_version"

            # Mettre à jour la version dans le fichier de configuration
            sed -i '' "s/^version=.*/version=\"$latest_version\"/" "$config_file"

            echo "Le script a été mis à jour à la version $latest_version"
            echo "Veuillez redémarrer le script pour appliquer les mises à jour."
        else
            echo "Mise à jour annulée."
        fi
    else
        echo "Votre script est déjà à jour."
    fi
}

# Fonction pour demander à l'utilisateur de configurer le répertoire des torrents.
demander_repertoire_torrents() {
    while true; do
        echo "Voulez-vous choisir le dossier contenant les torrents ? (Oui/Non)"
        read -r reponse_torrents
        case "$reponse_torrents" in
            Oui|oui|o|O|yes|Yes|y|Y)
                repertoire_torrents=$(choisir_dossier "Sélectionnez le dossier contenant les torrents")
                if [ -n "$repertoire_torrents" ]; then
                    # Mise à jour de la configuration avec le nouveau chemin
                    mettre_a_jour_config
                    break
                else
                    echo "Aucun dossier de torrents sélectionné."
                    return 1
                fi
                ;;
            non|Non|n|N|no|No)
                echo "Configuration annulée par l'utilisateur."
                exit 0
                ;;
            *)
                echo "Réponse invalide. Veuillez ressayer."
                ;;
        esac
    done
}
# Fonction pour demander à l'utilisateur d'installer l'interface web AriaNg.
demander_interface_web() {
    local mode="$1"
    local ariang_url="https://github.com/rickylawson/AriaNgDark/archive/refs/heads/master.zip"
    local ariang_zip="$config_dir/AriaNgDark-main.zip"
    local ariang_extract_dir="$config_dir/AriaNgDark-main"
    local repertoire_ariang="$config_dir/AriaNg"

    # Vérifie si AriaNg est déjà installé ou si les fichiers AriaNg ne sont pas trouvés
    if [ -d "$repertoire_ariang" ]; then
        install_ariang="1"
    elif [ "$install_ariang" = "1" ]; then
        echo "Les fichiers AriaNgDark ne sont pas trouvés. Réinitialisation de la configuration."
        install_ariang="0"
    fi
    mettre_a_jour_config

    # Activer l'installation si la fonction est appelée depuis le menu ou si `install_ariang` est vide
    if [ "$mode" = "menu" ] || [ -z "$install_ariang" ]; then
        echo "Voulez-vous installer l'interface web AriaNgDark ? (Oui/Non)"
        read -r reponse_web

        case "$reponse_web" in
            Oui|oui|o|O|yes|Yes|y|Y)
                echo "Téléchargement de l'interface web AriaNgDark."
                if curl -L "$ariang_url" -o "$ariang_zip" &> /dev/null; then
                    echo "Téléchargement réussi. Extraction en cours..."
                    if unzip -o "$ariang_zip" -d "$config_dir" &> /dev/null; then
                        mv "$ariang_extract_dir" "$repertoire_ariang"
                        echo "Interface web installée dans $repertoire_ariang."
                        install_ariang="1"
                    else
                        echo "Erreur lors de l'extraction de l'interface web."
                        rm -f "$ariang_zip"
                        return 1
                    fi
                else
                    echo "Erreur lors du téléchargement de l'interface web."
                    rm -f "$ariang_zip"
                    return 1
                fi
                rm -f "$ariang_zip"
                ;;
            Non|non|n|N|no|No)
                echo "Installation de l'interface web annulée."
                install_ariang="0"
                ;;
            *)
                echo "Réponse invalide. Veuillez ressayer."
                ;;
        esac
        mettre_a_jour_config
    fi
}
# Fonction pour charger la configuration.
load_config() {
    if [ ! -f "$config_file" ]; then
        echo "repertoire_torrents=" > "$config_file"
        echo "repertoire_destination=" >> "$config_file"
        echo "repertoire_poubelle=$HOME/.Trash" >> "$config_file"
        echo "install_ariang=" >> "$config_file"
        echo "repertoire_ariang=" >> "$config_file"
    fi
    source "$config_file"
}
# Fonction pour mettre à jour le fichier de configuration avec les nouveaux chemins.
mettre_a_jour_config() {
    {
        echo "repertoire_torrents=\"$repertoire_torrents\""
        echo "repertoire_destination=\"$repertoire_destination\""
        echo "repertoire_poubelle=\"$repertoire_poubelle\""
        echo "repertoire_ariang=\"$repertoire_ariang\""
        echo "install_ariang=\"$install_ariang\""
    } > "$config_file"
}


# --- FONCTIONS SPECIFIQUES DE GESTION DES FICHIER ET DOSSIERS ---
# Fonctions diverses pour la manipulation des dossiers et des torrents.
choisir_dossier() {
    zenity --file-selection --directory --title="$1" 2>/dev/null
}
# Fonction pour rafraîchir la liste des torrents.
rafraichir_liste_torrents() {
    if [[ $changement_dossier -eq 1 ]]; then
        echo "Actualisation de la liste des torrents..."
        lister_torrents
        changement_dossier=0
    fi
}
# Fonction pour modifier le dossier des torrents.
modifier_dossier_torrent() {
    echo "Choix d'un nouveau dossier pour les torrents."
    local nouveau_dossier=$(choisir_dossier "Choisissez le nouveau dossier des torrents")
    if [ -n "$nouveau_dossier" ]; then
        repertoire_torrents="$nouveau_dossier"
        mettre_a_jour_config
        echo "Dossier des torrents mis à jour : $repertoire_torrents"
    else
        echo "Aucun dossier n'a été sélectionné."
    fi
}
# Fonction pour modifier le dossier de destination.
modifier_dossier_destination() {
    echo "Choix d'un nouveau dossier de destination pour les téléchargements."
    local nouveau_dossier=$(choisir_dossier "Choisissez le nouveau dossier de destination")
    if [ -n "$nouveau_dossier" ]; then
        repertoire_destination="$nouveau_dossier"
        mettre_a_jour_config
        echo "Dossier de destination mis à jour : $repertoire_destination"
    else
        echo "Aucun dossier n'a été sélectionné."
    fi
}

# --- FONCTIONS DE TELECHARGEMENT DES TORRENTS ET GESTION DES TORRENTS ---
# Fonction pour télécharger un torrent spécifique.
telecharger_torrent() {
    local torrent="$1"
    local nom_fichier=$(basename "$torrent" .torrent)

    if [ -z "$repertoire_destination" ]; then
        echo "Aucun dossier de destination défini. Demande de sélection à l'utilisateur."
        repertoire_destination=$(choisir_dossier "Choisissez le dossier de destination")
        [ -n "$repertoire_destination" ] || return
        mettre_a_jour_config
    fi

    echo "Téléchargement du fichier : $nom_fichier dans le dossier : $repertoire_destination"
    if aria2c --seed-time=0 --follow-torrent=mem --file-allocation=none "$torrent" --dir="$repertoire_destination"; then
        rapport+="${GREEN}✅ Réussi - $nom_fichier${NC}\n"
        ((telechargements_reussis++))
    else
        rapport+="${RED}❌ Échoué - $nom_fichier${NC}\n"
        ((telechargements_echoues++))
    fi
    log_activity "Téléchargement de $nom_fichier: $( [[ $? -eq 0 ]] && echo 'Réussi' || echo 'Échoué')"
    mv "$torrent" "$repertoire_poubelle"
}
# Fonction pour traiter tous les fichiers .torrent.
traiter_torrents() {
    echo "Début du traitement des torrents..."
    shopt -s nullglob
    for torrent in "$repertoire_torrents"/*.torrent; do
        if [ -f "$torrent" ]; then
            echo "Téléchargement du torrent : $torrent"
            telecharger_torrent "$torrent"
        else
            echo "Aucun fichier .torrent trouvé."
        fi
    done
    shopt -u nullglob
}
# Fonction pour lister les torrents disponibles.
lister_torrents() {
    shopt -s nullglob
    local fichiers_torrent=("$repertoire_torrents"/*.torrent)
    echo "Nombre de fichiers torrents trouvés : ${#fichiers_torrent[@]}"
    if [ ${#fichiers_torrent[@]} -eq 0 ]; then
        echo -e "${RED}Aucun torrent disponible. 😔${NC}"
    else
        echo "Torrents disponibles :"
        for torrent in "${fichiers_torrent[@]}"; do
            local nom_fichier=$(basename "$torrent")
            echo -e "${GREEN} - $nom_fichier${NC}"
        done
    fi
    shopt -u nullglob
}
# Fonction pour afficher le rapport.
afficher_rapport() {
    if [ $telechargements_reussis -gt 0 ] || [ $telechargements_echoues -gt 0 ]; then
        echo -e "\n${GREEN}Rapport de Téléchargement :${NC}"
        echo -e "🔍 Dossier de destination : ${CYAN}$repertoire_destination${NC}"
        echo -e "$rapport"
    fi
}

# --- GESTION DE L'INTERFACE WEB ---
demarrer_aria2_rpc() {
    load_config

    # Vérifier et utiliser le répertoire de destination pour les téléchargements
    if [ -z "$repertoire_destination" ] || [ ! -d "$repertoire_destination" ]; then
        echo "Aucun dossier de destination valide défini. Demande de sélection à l'utilisateur."
        repertoire_destination=$(choisir_dossier "Choisissez le dossier de destination pour les téléchargements Aria2")
        [ -n "$repertoire_destination" ] || return
        mettre_a_jour_config
    fi

    if pgrep -x "aria2c" > /dev/null; then
        echo "Aria2 est déjà en cours d'exécution."
    else
        aria2c --enable-rpc --rpc-listen-all=true \
               --rpc-listen-port=6800 --rpc-allow-origin-all --seed-time=0 --follow-torrent=mem --file-allocation=none \
               --dir="$repertoire_destination" &> "$config_dir/aria2_rpc.log" &
        echo "Aria2 a été démarré avec l'interface RPC en arrière-plan."
        sleep 2
    fi
}
lancer_interface_web() {
    load_config
    # Vérifier le dossier de destination
    if [ -z "$repertoire_destination" ] || [ ! -d "$repertoire_destination" ]; then
        echo "Veuillez choisir le dossier de destination pour les téléchargements Aria2."
        repertoire_destination=$(choisir_dossier "Choisissez le dossier de destination pour les téléchargements Aria2")
        if [ -z "$repertoire_destination" ]; then
            echo "Aucun dossier de destination sélectionné. Opération annulée."
            return
        fi
        mettre_a_jour_config
    fi
    
    load_config
    demarrer_aria2_rpc

    # Ajouter des torrents à Aria2
    if [ -d "$repertoire_torrents" ]; then
        for torrent_file in "$repertoire_torrents"/*.torrent; do
            if [ -f "$torrent_file" ]; then
                base64_encoded_torrent=$(base64 -i "$torrent_file")
                # Envoi de la requête à Aria2 sans afficher la réponse
                curl -s -d "{\"jsonrpc\":\"2.0\",\"id\":\"qwer\",\"method\":\"aria2.addTorrent\",\"params\":[\"$base64_encoded_torrent\"]}" \
                http://localhost:6800/jsonrpc > /dev/null

                # Supprimer le fichier .torrent après l'avoir ajouté à Aria2
                rm -f "$torrent_file"
            fi
        done
        # Suppression des fichiers .torrent et .aria2 dans le dossier de destination
        find "$repertoire_destination" -type f \( -name '*.torrent' -o -name '*.aria2' \) -exec rm -f '{}' +
    else
        echo "Le dossier des torrents spécifié n'existe pas ou est inaccessible."
    fi

    # Ouvrir l'interface web
    ariang_web_dir="$config_dir/AriaNg"
    ariang_index_file="$ariang_web_dir/index.html"
    if [ -f "$ariang_index_file" ]; then
        echo "Ouverture de l'interface web AriaNg..."
        case "$(uname)" in
            Linux*)     xdg-open "$ariang_index_file" ;;
            Darwin*)    open "$ariang_index_file" ;;
            CYGWIN*|MINGW32*|MSYS*|MINGW*) start "$ariang_index_file" ;;
            *)          echo "Plateforme non prise en charge." ;;
        esac
    else
        echo "L'interface web AriaNg n'a pas été trouvée. Veuillez la télécharger d'abord."
    fi
}
trap 'arreter_aria2_rpc' EXIT
arreter_aria2_rpc() {
    local pid_file="$config_dir/aria2_rpc.pid"
    if [ -f "$pid_file" ]; then
        local aria2_pid=$(cat "$pid_file")
        kill "$aria2_pid" 2>/dev/null
        rm -f "$pid_file"
        echo "Aria2 a été arrêté."
    fi
}

# --- FONCTIONS DU MENU PRINCIPAL ET BOUCLE PRINCIPALE DU SCRIPT ---
verifier_et_mettre_a_jour_script
# Vérifie et charge la configuration
load_config
# Demander à l'utilisateur de configurer le répertoire des torrents si nécessaire.
if [ -z "$repertoire_torrents" ]; then
    if ! demander_repertoire_torrents; then
        exit 1
    fi
fi
demander_interface_web
# Fonction pour afficher le menu principal.
afficher_menu() {
    load_config
    local repertoire_ariang="$config_dir/AriaNg"
    clear
    print_message "$CYAN" "$ICON_INFO" " Répertoire des Torrents : ""$GREEN"$repertoire_torrents""
    print_message "$CYAN" "$ICON_INFO" " Répertoire de Destination : ""$GREEN"$repertoire_destination""
    echo
    print_message "$MAGENTA" "Liste des Torrents Disponibles :"
    lister_torrents
    echo
    afficher_rapport
    printf "${BLUE}1. 📥 Démarrer le Téléchargement   2. 🔄 Rafraîchir la Liste\n${NC}"
    printf "${BLUE}3. 📁 Changer Répertoire Torrents  4. 📂 Changer Répertoire de Destination\n${NC}"

    if [ "$install_ariang" = "1" ] && [ -d "$repertoire_ariang" ]; then
        printf "${BLUE}5. 🌐 Lancer l'Interface Web       6. ❌ Quitter\n${NC}"
    else
        printf "${BLUE}5. 🌐 Installer l'Interface Web    6. ❌ Quitter\n${NC}"
    fi
    printf "${YELLOW}> ${NC}"
    read -r choix_utilisateur
    echo
}
# Boucle principale du script.
while true; do
    afficher_menu
    case $choix_utilisateur in
        1) traiter_torrents ;;
        2) lister_torrents ;;
        3) modifier_dossier_torrent ;;
        4) modifier_dossier_destination ;;
        5)
            if [ "$install_ariang" != "1" ]; then
                demander_interface_web "menu"
            else
                lancer_interface_web
            fi
            ;;
        6) exit 0 ;;
        *) print_message "$RED" "$ICON_WARNING" "Option invalide. Veuillez réessayer." ;;
    esac
done

