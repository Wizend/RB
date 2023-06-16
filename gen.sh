function rb() {
    /root/rb.sh
}

function ..() {
    cd ..
}

function cd() {
    builtin cd "$@" && ls
}

function maj() {
    sudo apt-get update && sudo apt-get upgrade
}

function extract() {
  if [ -f $1 ] ; then
      case $1 in
          *.tar.bz2)   tar xjf $1     ;;
          *.tar.gz)    tar xzf $1     ;;
          *.bz2)       bunzip2 $1     ;;
          *.rar)       unrar e $1     ;;
          *.gz)        gunzip $1      ;;
          *.tar)       tar xf $1      ;;
          *.tbz2)      tar xjf $1     ;;
          *.tgz)       tar xzf $1     ;;
          *.zip)       unzip $1       ;;
          *.Z)         uncompress $1  ;;
          *.7z)        7z x $1        ;;
          *)           echo "'$1' ne peut pas être extrait via extract()" ;;
      esac
  else
      echo "'$1' n'est pas un fichier valide"
  fi
}

function h() {
    history | grep $1
}

function cpu() {
    top -bn1 | grep "Cpu(s)" | awk '{print "CPU utilisé: " $2 "% | Mémoire utilisée: " $4}'
}

function mem() {
    free -m | awk 'NR==2{printf "Mémoire utilisée: %s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2 }'
}

function viderdns() {
    sudo resolvectl flush-caches
}

function grosfichiers() {
    find . -type f -exec ls -lh {} \; | awk '{ print $9 ": " $5 }' | sort -hr -k2 | head -n 10
}

function genmdp() {
    < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-16};echo;
}

function myip() {
    curl ipinfo.io/ip
}

function cpclip() {
    cat $1 | xclip -selection clipboard
}

function tarzip() {
    tar -czvf "$1".tar.gz -C "$2" "$1"
    rm -r "$1"
}

function lh() { 
    ls -lh .[^.]* 
}

function mkcd() { 
    mkdir -p "$@" && cd "$_"; 
}
