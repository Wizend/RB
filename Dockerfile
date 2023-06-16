FROM ubuntu:20.04

RUN apt-get update && apt-get install -y dos2unix openssl cron && apt-get clean

RUN mkdir /rb
WORKDIR /rb

RUN mkdir /rb/temp

RUN mkdir /var/lib/checksums
RUN mkdir /rb/backup
RUN mkdir /rb/testfolder
RUN echo "Hello from backup" > ./testfolder/truc.txt
RUN echo "Hello fderfrfrom backup" > ./backup/f.txt
RUN echo "Helrrrrrrrrrrrrrrrrrlo from backup" > ./backup/d.txt

# Copie des fichiers dans le répertoire de l'utilisateur
COPY ./backup_script.conf /etc/backup_script.conf
COPY ./rotate_backup_v4.sh /rb.sh

# Convertir les fichiers en utilisant dos2unix
RUN dos2unix /etc/backup_script.conf && dos2unix /rb.sh

ENTRYPOINT ["../rb.sh"]