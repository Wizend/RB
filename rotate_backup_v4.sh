#!/bin/bash

# CONFIGURATION ----------------------

# Chemin du fichier de configuration
CONFIG_FILE="/etc/backup_script.conf"

# Fonction pour charger les paramètres depuis le fichier de configuration
function load_config() {
  # Tester l'existence du fichier de configuration
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
  else
    echo "Fichier de configuration '$CONFIG_FILE' introuvable."
    exit 1
  fi
}

# -------------------------------------


# BACKUPS -----------------------------

# Fonction qui affiche les sauvegardes
function show_backups() {
  echo "Liste des sauvegardes disponibles :"
  # Utiliser find pour trouver les fichiers de sauvegarde dans le dossier sélectionné par l'utilisateur
  local backups=($(find ${BACKUP_DIR} -type f -name "backup_*"))

  # Tester et boucler sur la liste de fichier
  if [[ ${#backups[@]} -eq 0 ]]; then
    echo "Aucune sauvegarde à afficher."
  else
    # Afficher la liste des fichiers trouvé avec un numero devant
    for ((i=0; i<${#backups[@]}; i++)); do
      echo "$((i+1)). ${backups[$i]}"
    done
  fi
}

# Fonction pour effectuer la sauvegarde
function perform_backup() {
  local timestamp=$(date +"%Y-%m-%d_%H-%M")
  local backup_folder="${BACKUP_DIR}/backup_${timestamp}"

  # Créer un fichier de backup pour accueillir les fichiers qui vont être sauvegardés
  mkdir "$backup_folder"

  # Boucler sur les fichiers désigné par l'utilisateur dans le fichier de config
  for item in "${FILES_TO_BACKUP[@]}"; do
    if [ -f "$item" ]; then
      # Le fichier existe, le copier
      cp "$item" "$backup_folder" || handle_errors "Échec de la copie du fichier : $item" "$?"

      # Enregistrer le checksum du fichier
      save_checksum "$item"

    elif [ -d "$item" ]; then
      # Le dossier existe, copier son contenu
      cp -R "$item" "$backup_folder" || handle_errors "Échec de la copie du dossier : $item" "$?"

      # Enregistrer les checksums des fichiers du dossier
      while IFS= read -r -d '' file; do
        save_checksum "$file"
      done < <(find "$item" -type f -print0)
    else
      # Ni un fichier ni un dossier valide
      handle_errors "Fichier ou dossier invalide : $item"
    fi
  done

  write_log "Sauvegarde effectuée : ${backup_folder}"

  # Tester la variable pour afficher plus ou moins de log
  if [ "$NOTIFY_SUCCESS" = true ]; then
    echo -e "La sauvegarde du ${timestamp} a été effectuée avec succès." # | mail -s "Notification de sauvegarde réussie" "$ADMIN_EMAIL"
    write_log "Notification envoyée à ${ADMIN_EMAIL} : sauvegarde réussie"
  fi

  # Appel des fonctions de compression et encryption de sauvegardes avec testes des variables
  if [ "$ADD_COMPRESSION" = true ]; then
    compress_backups || handle_errors "Échec de la compression du fichier : $file" "$?"
  fi
  if [ "$ADD_ENCRYPTION" = true ]; then
    encrypt_backups || handle_errors "Échec de la compression du fichier : $file" "$?"
  fi
}

# Fonction pour compresser les sauvegardes
function compress_backups() {
  # Boucler sur les fichier dans le dossier de backup
  for folder in "${BACKUP_DIR}/backup_"*; do
    # Utiliser une fonction provenant de 'gen.sh' pour compresser la sauvegarde
    tarzip $folder $BACKUP_DIR || handle_errors "Échec de la compression de la sauvegarde : $folder" "$?"
    write_log "Sauvegarde compressée : ${backup_archive}"
  done

  # Tester la variable pour afficher plus ou moins de log
  if [ "$NOTIFY_SUCCESS" = true ]; then
    echo -e "La compression du ${timestamp} a été effectuée avec succès." # | mail -s "Notification de sauvegarde réussie" "$ADMIN_EMAIL"
    write_log "Notification envoyée à ${ADMIN_EMAIL} : compression réussie"
  fi
}

# Fonction pour chiffrer les sauvegardes
function encrypt_backups() {
  # local encryption_key="$ENCRYPTION_KEY"

  # Boucler sur les fichiers compressé
  for file in "${BACKUP_DIR}/backup_"*.tar.gz; do
    local encrypted_file="${file}.enc"
    # Chiffrer les fichiers compressés
    openssl enc -salt -in "$file" -out "$encrypted_file" || handle_errors "Échec de l'encryption de la sauvegarde : $folder" "$?"
    rm "$file"
    write_log "Sauvegarde chiffrée : ${encrypted_file}"
  done

  # Tester la variable pour afficher plus ou moins de log
  if [ "$NOTIFY_SUCCESS" = true ]; then
    echo -e "Le chiffrement du ${timestamp} a été effectuée avec succès." # | mail -s "Notification de sauvegarde réussie" "$ADMIN_EMAIL"
    write_log "Notification envoyée à ${ADMIN_EMAIL} : chiffrement réussie"
  fi
}

# Fonction pour gérer la rotation des sauvegardes
function rotate_backups() {
  local current_date=$(date +"%Y-%m-%d_%H-%M")
  local oldest_date=$(date -d "$DAYS_TO_KEEP days ago" +"%Y-%m-%d_%H-%M")

  # Utiliser find pour trouver les fichiers de sauvegarde dans le dossier sélectionné par l'utilisateur
  local backups=($(find ${BACKUP_DIR} -type f -name "backup_*.tar.gz.enc"))
  local found_backups=false

  # Boucler sur les sauvevarde dans le fichier choisi par l'utilisateur
  if [[ ${#backups[@]} -eq 0 ]]; then
    echo "Aucune sauvegarde à supprimer."
  else
    # Si des fichiers sont trouvé on boucle dessus pour récupérer leur nom
    for files in "${backups[@]}"; do
      local backup_date=$(basename "$files" | cut -d '_' -f 2)

      # Comparer les date des fichiers pour effectuer la rotation
      if [[ "$backup_date" < "$oldest_date" ]]; then
        rm -r "$files" || handle_errors "Échec de la suppression de la sauvegarde : $files" "$?"
        write_log "Sauvegarde supprimée : ${files}"

        # Tester la variable pour afficher plus ou moins de log
        if [ "$NOTIFY_SUCCESS" = true ]; then
          echo -e "La sauvegarde du ${$oldest_date} a été supprimé avec succès." # | mail -s "Notification de sauvegarde réussie" "$ADMIN_EMAIL"
          write_log "Notification envoyée à ${ADMIN_EMAIL} : sauvegarde supprimé"
        fi
      fi
    done
  fi
}

# Fonction pour restaurer des fichiers spécifiques à partir d'une sauvegarde
function restore_backup() {
  echo "Liste des sauvegardes disponibles :"
  # Utiliser find pour trouver les fichiers de sauvegarde dans le dossier sélectionné par l'utilisateur
  local backups=($(find -type f -name "backup_*.tar.gz.enc"))

  # Tester et boucler sur la liste de fichier
  if [[ ${#backups[@]} -eq 0 ]]; then
    echo "Aucune sauvegarde disponible."
  else
    # Afficher la liste des fichiers trouvé avec un numero
    for ((i=0; i<${#backups[@]}; i++)); do
      echo "$((i+1)). ${backups[i]}"
    done
  fi

  read -p "Choisissez le numéro de la sauvegarde à partir de laquelle restaurer les fichiers : " choice
  # Tester le choix de l'utilisateur
  if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -gt 0 ] && [ $choice -le ${#backups[@]} ]; then
    local selected_backup="${backups[choice-1]}"
    echo "Restauration de fichiers à partir de la sauvegarde : ${selected_backup}"

    # Créer un fichier temporaire pour l'unzip
    local temp_dir=$(mktemp -d)
    tar -xf "$selected_backup" -C "$temp_dir" || handle_errors "Échec de l'extraction de la sauvegarde : $selected_backup" "$?"

    local backup_files=("$temp_dir"/*)

    echo "Liste des fichiers disponibles dans la sauvegarde :"
    # Boucler sur les fichiers dezippé pour les afficher avec un numero
    for ((i=0; i<${#backup_files[@]}; i++)); do
      echo "$((i+1)). ${backup_files[i]}"
    done

    read -p "Choisissez le numéro des fichiers à restaurer (séparés par des espaces) : " file_choices
    local choices_arr=($file_choices)
    local restored_files=()

    for choice in ${choices_arr[@]}; do
      # Tester le choix de l'utilisateur
      if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -gt 0 ] && [ $choice -le ${#backup_files[@]} ]; then
        local selected_file="${backup_files[choice-1]}"
        echo "Restauration du fichier : ${selected_file}"
        cp -r "$selected_file" /
        # Enregistrer le fichier selectionné dans une variable
        restored_files+=("$selected_file")
      else
        echo "Option invalide. Ignorée : $choice"
      fi
    done

    # Boucler sur la variable qui a les fichiers restaurés comme valeur pour les afficher
    if [ ${#restored_files[@]} -gt 0 ]; then
      local restored_files_str=$(IFS=", "; echo "${restored_files[*]}")
      write_log "Fichiers restaurés : $restored_files_str"
    fi

    # Supprimer le répertoire temporaire
    rm -rf "$temp_dir" 
  else
    echo "Option invalide. Veuillez réessayer."
  fi
}

# --------------------------------------


# INTEGRITY TEST -----------------------

# Fonction pour décompresser les fichiers de sauvegarde
function unzip_backup() {
  local archive="$1"
  local destination="$2"
 
  # Utiliser tar pour unzip et déplacer le fichier
  tar -xf "$archive" -C "$destination" || handle_errors "Échec de la décompression de l'archive : $archive" "$?"

  # Tester la variable pour afficher plus ou moins de log
  if [ "$NOTIFY_SUCCESS" = true ]; then
    echo -e "La decompression de l'archive du ${archive} a été effectuée avec succès." # | mail -s "Notification de sauvegarde réussie" "$ADMIN_EMAIL"
    write_log "Notification envoyée à ${ADMIN_EMAIL} : décompression réussie"
  fi

}

# Fonction pour enregistrer le checksum d'un fichier
function save_checksum() {
  local file="$1"
  # Récupérer le checksum du fichier avec la commande sha256sum
  local checksum=$(sha256sum "$file" | awk '{print $1}')
  local timestamp=$(date +"%Y-%m-%d_%H-%M")
  local checksum_file="${CHECKSUM_DIR}/checksum_${timestamp}.txt"

  # On enregistre le checksum précédemment récupéré dans le fichier de checksum
  echo "$timestamp $checksum $file" >> "$checksum_file"

  # Tester la variable pour afficher plus ou moins de log
  if [ "$NOTIFY_SUCCESS" = true ]; then
    echo -e "Fichier sauvegardé : $file (checksum : $checksum)" # | mail -s "Notification de sauvegarde réussie" "$ADMIN_EMAIL"
    write_log "Fichier sauvegardé : $file (checksum : $checksum)"
  fi
}

# Fonction pour comparer les checksums des fichiers décompressés avec les checksums précédents
function compare_checksums() {
  local backup_date="$1"
  local temp_folder="$2"
  local corrupted_files=""
  local checksum_file="/var/lib/checksums/checksum_${backup_date}.txt"

  # Tester l'existence du fichier de checksum
  if [ -f "$checksum_file" ]; then
    # Lire le fichier de checksum et enregistrer les arguments 2 et 3 du fichiers dans des variables
    while IFS= read -r line; do
      local checksum=($(echo "$line" | awk '{print $2}'))
      local file=($(echo "$line" | awk '{print $3}'))

      # Tester l'existence d'un fichier dans la sauvegarde dezippé
      for unzip_file in "${TEMP_DIR}"/*.*; do
        # Tester la correspondance de nom entre les fichiers dezippé et les fichiers trouvé dans le fichier de checksum
        if [ "$file" == "$(basename "$unzip_file")" ]; then
          # Récupérer le checksum des fichiers dezippé
          local computed_checksum=$(sha256sum "$unzip_file" | awk '{print $1}')
          # Comparer les checksum des fichiers entre eux
          if [ "$checksum" != "$computed_checksum" ]; then
            # Enregistrer le nom du fichier pour lequel le checksum ne correpond pas, dans une variable
            corrupted_files+="\n${unzip_file}"
          fi
          break
        fi
      done
    done < "$checksum_file"
  fi

  # Tester si la variable de fichier corrompues est pleine pour afficher le résultat en fonction
  if [ -z "$corrupted_files" ]; then
    echo "La vérification de l'intégrité a réussi pour la sauvegarde : $backup_date"
    write_log "Vérification de l'intégrité réussie pour la sauvegarde : $backup_date"
  else
    echo -e "Les fichiers de sauvegarde suivants sont corrompus :$corrupted_files"
    write_log "Alerte envoyée à ${ADMIN_EMAIL} : sauvegardes corrompues"
  fi
}

# Fonction pour vérifier l'intégrité des fichiers de sauvegarde
function check_backup_integrity() {
  local timestamp=$(date +"%Y-%m-%d_%H-%M")
  local corrupted_files=""
  # Utiliser find pour trouver les fichiers de sauvegarde dans le dossier sélectionné par l'utilisateur
  local backups=($(find "${BACKUP_DIR}" -type f -name "backup_*"))

  # Boucler sur la variable pour tester l'existence des fichiers
  if [[ ${#backups[@]} -eq 0 ]]; then
    echo "Aucune sauvegarde à vérifier."
  else
    # Boucler sur les fichiers trouvé pour récupéré la date edans une variable
    for folder in "${backups[@]}" ; do
      local backup_date=$(basename "$folder" | cut -d '_' -f 2-3 | xargs basename --suffix=".tar.gz.enc")
      local temp_folder="${TEMP_DIR}/backup_${backup_date}"

      # Créer un fichier temporaire
      mkdir "$temp_folder"

      # Unzip les fichiers
      unzip_backup "$folder" "$temp_folder"

      # Ajouter l'entrée dans les logs
      write_log "Vérification de l'intégrité : $folder"

      # Comparer les checksums des fichiers décompressés avec les checksums précédents
      compare_checksums "$backup_date" "$temp_folder"
    done
  fi

  # Supprimer le dossier temporaire
  rm -rf "$temp_folder"

  if [ -n "$corrupted_files" ]; then
    echo -e "Les fichiers de sauvegarde suivants sont corrompus :$corrupted_files" # | mail -s "Alerte Intégrité des Sauvegardes" "$ADMIN_EMAIL"
    write_log "Alerte envoyée à ${ADMIN_EMAIL} : sauvegardes corrompues"
  fi
}

# --------------------------------------


# AUTOMATISATION --------------------------

# Fonction pour planifier une sauvegarde automatique
function schedule_backup() {
  # Demander les paramètres à l'utilisateur
  read -p "Entrez l'intervalle de sauvegarde (en minutes) : " interval
  read -p "Entrez l'heure de départ de la sauvegarde (au format HH:MM) : " start_time

  # Enregistrer les paramètres dans des variables
  local cron_expression="$((interval%60)) $((interval/60)) * * *"
  local cron_job="$start_time bash -c '. /rb.sh; perform_backup'"

  # Enregistrer la regle cron
  (crontab -l 2>/dev/null; echo "$cron_expression $cron_job") | crontab -
  write_log "La sauvegarde automatique a été planifiée avec succès."
}

# Fonction pour afficher les cron jobs existants
function view_cron_jobs() {
  crontab -l
}

# --------------------------------------


# GEN FUNCTION -------------------------

# Fonction pour afficher les ressources système utilisé
function cpu() {
    top -bn1 | grep "Cpu(s)" | awk '{print "CPU utilisé: " $2 "% | Mémoire utilisée: " $4}'
}

# Fonction pour dezipper n'importe qu'elle fichier
function tarzip() {
    local folder_path="$1"
    local folder_name=$(basename "$folder_path")
    local destination_dir="$2"

    # Utiliser la fonction tar pour dezipper un fichier
    tar -czvf "${destination_dir}/${folder_name}.tar.gz" -C "$folder_path" .
    # Supprimer le fichier utilisé
    rm -r "${folder_path:?}/"*
}

# --------------------------------------


# LOGS FUNCTION ------------------------

# Fonction pour effectuer la rotation des fichiers de journal
function rotate_logs() {
  local log_files=("$LOG_FILE"*)

  # On teste le nombre de fichier de log dans le dossier de log
  if [ ${#log_files[@]} -gt $MAX_LOGS ]; then
    local num_logs_to_remove=$(( ${#log_files[@]} - $MAX_LOGS ))

    # Tri des fichiers de journal par date de création (du plus ancien au plus récent)
    IFS=$'\n' log_files=($(ls -rt "$LOG_FILE"*))
    unset IFS

    # Boucler sur la variable contenant le nombre de fichier de log a supprimer
    for ((i=0; i<num_logs_to_remove; i++)); do
      local log_file="${log_files[$i]}"
      
      # Tester l'existence des fichiers à supprimer
      if [ -f "$log_file" ]; then
        # Les supprimer
        rm "$log_file" || handle_errors "Échec de la suppression du fichier de journal : $log_file" "$?"
      else
        handle_errors "Le fichier de journal à supprimer n'existe pas : $log_file" 1
      fi
    done
  fi
}

# Fonction pour écrire dans les logs
function write_log() {
  local message=$1
  local timestamp=$(date +"%Y-%m-%d_%H:%M")
  # Fonction provenant de 'gen.sh' permettant de voir les ressources systèmes
  local system_resources=$(cpu)
  local status="[SUCCESS]"

  # Tester l'existence d'un code erreur, si oui afficher une erreur
  if [ "$?" -ne 0 ]; then
    status="[ERROR]"
  fi

  # Créer le message de log général contenant : la date et l'heure, le status, le message et les ressources système utilisé
  local log_message="[${timestamp}] ${status} ${message} | ${system_resources}"

  # Vérifier le niveau de détail du journal en testant la variable correspondante
  case "$LOG_LEVEL" in
    "info")
      echo "$log_message" >> "$LOG_FILE"
      ;;
    "debug")
      echo "$log_message" | tee -a "$LOG_FILE"
      ;;
  esac

  # Appel de la fonction pour effectuer la rotation des fichiers de journal
  rotate_logs
}

# Fonction pour gérer les exceptions et erreurs
function handle_errors() {
  local error_message=$1
  local error_code=$2

  # On appel la fonction pour l'écriture des logs pour chaque message d'erreur
  write_log "ERREUR (${error_code}) : ${error_message}"
  echo -e "ERREUR (${error_code}) : ${error_message}"

  # Tester la variable pour afficher plus ou moins de log
  if [ "$NOTIFY_ERRORS" = true ]; then
    echo -e "Une erreur s'est produite lors de l'exécution du script de sauvegarde :\n\n${error_message}\n" | # mail -s "Erreur lors de l'exécution du script de sauvegarde" "$ADMIN_EMAIL"
    write_log "Notification d'erreur envoyée à ${ADMIN_EMAIL}"
  fi

  exit "$error_code"
}

# Gestion des erreurs lors de la restauration
function handle_restore_errors() {
  local error_message=$1
  write_log "ERREUR lors de la restauration : ${error_message}"
  echo -e "ERREUR lors de la restauration : ${error_message}"
  exit 1
}

# --------------------------------------


# Fonction pour afficher le menu de l'interface utilisateur
function main() {

  # Gestion des exceptions et erreurs
  trap "handle_errors 'Une exception inattendue s'est produite.' '$?'" ERR

  # Chargement des paramètres de configuration
  load_config

  # Afficher le menu
  echo
  echo "=== Menu ===" $(date +"%d-%m-%Y %H:%M")
  echo 
  echo "1. Effectuer une sauvegarde"
  echo "2. Afficher les sauvegardes"
  echo "3. Rotation des sauvegardes"
  echo "4. Restaurer une sauvegarde complète"
  echo "5. Vérifier l'intégrité des sauvegardes"
  echo "6. Planifier une sauvegarde automatique"
  echo "7. Afficher les cron jobs existants"
  echo "8. Quitter"
  echo
  read -p "Choisissez une option : " choice
  echo

  # Appel des fonctions nécessaires
  case $choice in
    1) perform_backup;;
    2) show_backups;;
    3) rotate_backups;;
    4) restore_backup;;
    5) check_backup_integrity;;
    6) schedule_backup;;
    7) view_cron_jobs;;
    8) exit;;
    *) echo "Option invalide. Veuillez réessayer.";;
  esac

  main

  /bin/bash -it

}

main