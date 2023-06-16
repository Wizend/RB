# Notice d'Utilisation

## Mise en place de l'environnement

Les tests ont été effectué dans un conteneur Docker, je vais donc vous présenter comment le refaire. Mais toutes machines capable de comprendre le bash sera capable de lancer le script.

1. Lancer une invite de commande
2. Télécharger le dossier pour le script : `ssh git@github.com:Wizend/RB.git`
3. Une fois téléchargé aller dans le repertoire de rb : `cd rb/`
4. Lancer l'application Docker.
5. Executer la commande suivante pour monter l'image : `docker rmi bash | docker build -t bash .`
6. Executer la commande suivante pour lancer un conteneur avec cette image : `docker run -it bash`

Le conteneur et le script sont maintenant lancés, vous pouvez utiliser le script directement.

## Les Variables

Le script utilise un fichier de variable pour être plus polyvalent, cela vous permettra également de personnaliser ce que vous souhaitez dans le script :

### Répertoire des sauvegardes :
```
BACKUP_DIR="/rb/backup"
```

### Liste des fichiers (ou dossier) à sauvegarder :
```
FILES_TO_BACKUP=(
  "/rb/testfolder/"
  "/rb/backup/f.txt"
  "/rb/backup/d.txt"
)
```

### Envoyer une notification en cas de réussite (avec mail) :
```
NOTIFY_SUCCESS=true
```

### Adresse e-mail pour les notifications :
```
ADMIN_EMAIL="admin@example.com"
```

### Envoyer une notification en cas d'erreur :
```
NOTIFY_ERRORS=true
```

### Ajoute la compression des fichiers au moment de la sauvegarde :
```
ADD_COMPRESSION=true
```

### Ajoute la encryption des fichiers au moment de la sauvegarde :
```
ADD_ENCRYPTION=true
```

### Nombre de jours à conserver les sauvegardes :
```
DAYS_TO_KEEP=7
```

### Emplacement du fichier de stockage des empreintes :
```
CHECKSUM_DIR="/var/lib/checksums"
```

### Emplacement des fichiers temporaires :
```
TEMP_DIR="/rb/temp"
```

### Emplacement du fichier de restauration :
```
RESTORE_LOCATION="/rb/backup_restore"
```

### Chemin du fichier de journal :
```
LOG_FILE="/var/log/backup.log"
```

### Niveau de détail du journal (info, debug) :
```
LOG_LEVEL="info"
```