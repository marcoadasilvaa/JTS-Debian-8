#!/bin/bash

# Configuración de colores
resaltado="\033[43m\033[30m"
verde="\033[33m"
normal="\033[40m\033[37m"


# Escribir el título en colores
function write_title() {
    echo " "
    echo -e "$resaltado $1 $normal"
    say_continue
}


# Mostrar mensaje "Done."
function say_done() {
    echo " "
    echo -e "$verde Done. $normal"
    say_continue
}


# Preguntar para continuar
function say_continue() {
    echo -n " Para SALIR, pulse la tecla x; sino, pulse ENTER para continuar..."
    read acc
    if [ "$acc" == "x" ]; then
        exit
    fi
    echo " "
}


# Obtener la IP del seridor
function __get_ip() {
    linea=`ifconfig eth0 | grep -e "inet\ addr:"`
    serverip=`python scripts/get_ip.py $linea`
    echo $serverip
}


# Copiar archivos de configuración locales
function tunning() {
    whoapp=$1
    cp templates/$whoapp /root/.$whoapp
    cp templates/$whoapp /home/$username/.$whoapp
    chown $username:$username /home/$username/.$whoapp
    say_done
}


# Agregar el comando blockip
function add_command_blockip() {
    echo "  ===> blockip [IP] -- Agregar bloqueo de IP a iptables (OK)"
    echo "  ===> unblockip [IP] -- Eliminar bloqueo de IP en iptables y route (OK)"
    cp commands/blockip /sbin/jts-iptables
    chmod +x /sbin/jts-iptables
    ln -s /sbin/jts-iptables /sbin/blockip
    ln -s /sbin/jts-iptables /sbin/unblockip
    echo -n "  Agregando páginas man al manual blockip(8) y unblockip(8)"
    cp commands/manpages/blockip /usr/share/man/man8/blockip.8
    gzip -q /usr/share/man/man8/blockip.8
    cp commands/manpages/unblockip /usr/share/man/man8/unblockip.8
    gzip -q /usr/share/man/man8/unblockip.8
    echo " (Listo!)"
}

