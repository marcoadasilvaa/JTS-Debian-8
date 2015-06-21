#!/bin/bash

# JackTheStripper v1.0
# Deployer for Debian 8
# 
# @license         http://www.gnu.org/licenses/gpl.txt  GNU GPL 3.0
# @author          Eugenia Bahit <ebahit@linux.com>
# @link            http://www.eugeniabahit.com/proyectos/jackthestripper
# @Contributor     Jason Soto <jason_soto@jsitech.com>
# @link            http://www.jsitech.com/jackthestripper

source helpers.sh


# 0. Verificar si es usuario root o no 
function is_root_user() {
    if [ "$USER" != "root" ]; then
        echo "Permiso denegado."
        echo "Este programa solo puede ser ejecutado por el usuario root"
        exit
    else
        clear
        cat templates/texts/welcome
    fi
}


# 1. Configurar Hostname
function set_hostname() {
    write_title "1. Configurar Hostname"
    echo -n " ¿Desea configurar un hostname? (y/n): "; read config_host
    if [ "$config_host" == "y" ]; then
        serverip=$(__get_ip)
        echo " Ingrese un nombre para identificar a este servidor"
        echo -n " (por ejemplo: myserver) "; read host_name
        echo -n " ¿Cuál será el dominio principal? "; read domain_name
        echo $host_name > /etc/hostname
        hostname -F /etc/hostname
        echo "127.0.0.1    localhost.localdomain      localhost" >> /etc/hosts
        echo "$serverip    $host_name.$domain_name    $host_name" >> /etc/hosts
    fi
    say_done
}


# 2. Configurar zona horaria
function set_hour() {
    write_title "2. Configuración de la zona horaria"
    dpkg-reconfigure tzdata
    say_done
}


#  3. Actualizar el sistema
function sysupdate() {
    write_title "3. Actualización del sistema"
    apt-get update
    apt-get upgrade -y
    say_done
}


#  4. Crear un nuevo usuario con privilegios
function set_new_user() {
    write_title "4. Creación de un nuevo usuario"
    echo -n " Indique un nombre para el nuevo usuario: "; read username
    adduser $username
    usermod -a -G sudo $username
    say_done
}


#  5. Instrucciones para generar una RSA Key
function give_instructions() {
    serverip=$(__get_ip)
    write_title "5. Generación de llave RSA en su ordenador local"
    echo " *** SI NO TIENE UNA LLAVE RSA PÚBLICA EN SU ORDENADOR, GENERE UNA ***"
    echo "     Siga las instrucciones y pulse INTRO cada vez que termine una"
    echo "     tarea para recibir una nueva instrucción"
    echo " "
    echo "     EJECUTE LOS SIGUIENTES COMANDOS:"
    echo -n "     a) ssh-keygen "; read foo1
    echo -n "     b) scp .ssh/id_rsa.pub $username@$serverip: "; read foo2
    say_done
}


#  6. Mover la llave pública RSA generada
function move_rsa() {
    write_title "6. Se moverá la llave pública RSA generada en el paso 5"
    echo " Ejecute el comando a Continuación para copiar la llave"
    echo " Presione ENTER cuando haya Finalizado "
    echo " ssh-copy-id -i $HOME/.ssh/id_rsa.pub $username@$serverip "
    say_done
    chmod 700 /home/$username/.ssh
    chmod 600 /home/$username/.ssh/authorized_keys
    chown -R $username:$username /home/$username/.ssh
    say_done
}


#  7. Securizar SSH
function ssh_reconfigure() {
    write_title "7. Securizar accesos SSH"
    sed s/USERNAME/$username/g templates/sshd_config > /etc/ssh/sshd_config
    service ssh restart
    say_done
}


#  8. Establecer reglas para iptables
function set_iptables_rules() {
    write_title "8. Establecer reglas para iptables (firewall)"
    cat templates/iptables > /etc/iptables.firewall.rules
    iptables-restore < /etc/iptables.firewall.rules
    say_done
}


#  9. Crear script de automatizacion iptables
function create_iptable_script() {
    write_title "9. Crear script de automatización de reglas de iptables tras reinicio"
    cat templates/firewall > /etc/network/if-pre-up.d/firewall
    chmod +x /etc/network/if-pre-up.d/firewall
    say_done
}


# 10. Instalar fail2ban
function install_fail2ban() {
    # para eliminar una regla de fail2ban en iptables utilizar:
    # iptables -D fail2ban-ssh -s IP -j DROP
    write_title "10. Instalar Sendmail y fail2ban"
    apt-get install sendmail
    apt-get install fail2ban
    say_done
}


# 11. Instalar, Configurar y Optimizar MySQL
function install_mysql() {
    write_title "11. Instalar MySQL"
    apt-get install mysql-server
    echo -n " configurando MySQL............ "
    cp templates/mysql /etc/mysql/my.cnf; echo " OK"
    mysql_secure_installation
    service mysql restart
    say_done
}


# 12. Instalar, configurar y optimizar PHP
function install_php() {
    write_title "12. Instalar PHP 5 + Apache 2"
    apt-get install apache2
    apt-get install php5 php5-cli php-pear
    apt-get install php5-mysql python-mysqldb
    echo -n " reemplazando archivo de configuración php.ini..."
    cp templates/php /etc/php5/apache2/php.ini; echo " OK"
    service apache2 restart
    mkdir /srv/websites
    chown -R $username:$username /srv/websites
    write_title "Aloje sus WebApps en el directorio /srv/websites"
    echo -n "Si desea alojar sus aplicaciones en otro directorio, por favor, "
    echo -n "establezca la nueva ruta en la directiva open_base del archivo "
    echo "/etc/php5/apache2/php.ini"
    say_done
}


# 13. Instalar ModSecurity
function install_modsecurity() {
    write_title "13. Instalar ModSecurity"
    apt-get install libxml2 libxml2-dev libxml2-utils
    apt-get install libaprutil1 libaprutil1-dev
    apt-get install libapache2-modsecurity
    service apache2 restart
    say_done
}


# 14. Configurar OWASP para ModSecuity
function install_owasp_core_rule_set() {
    write_title "14. Instalar OWASP ModSecurity Core Rule Set"

    for archivo in /usr/share/modsecurity-crs/base_rules/*
        do ln -s $archivo /usr/share/modsecurity-crs/activated_rules/
    done

    for archivo in /usr/share/modsecurity-crs/optional_rules/*
        do ln -s $archivo /usr/share/modsecurity-crs/activated_rules/
    done
    echo "OK"

    sed s/SecRuleEngine\ DetectionOnly/SecRuleEngine\ On/g /etc/modsecurity/modsecurity.conf-recommended > salida
    mv salida /etc/modsecurity/modsecurity.conf
    
    echo 'SecServerSignature "AntiChino Server 1.0.4 LS"' >> /usr/share/modsecurity-crs/modsecurity_crs_10_setup.conf
    echo 'Header set X-Powered-By "Plankalkül 1.0"' >> /usr/share/modsecurity-crs/modsecurity_crs_10_setup.conf
    echo 'Header set X-Mamma "Mama mia let me go"' >> /usr/share/modsecurity-crs/modsecurity_crs_10_setup.conf

    a2enmod headers
    service apache2 restart
    say_done
}


# 15. Configurar y optimizar Apache
function configure_apache() {
    write_title "15. Finalizar configuración y optimización de Apache"
    cp templates/apache /etc/apache2/apache2.conf
    echo " -- habilitar ModRewrite"
    a2enmod rewrite
    service apache2 restart
    say_done
}


# 16. Instalar ModEvasive
function install_modevasive() {
    write_title "16. Instalar ModEvasive"
    echo -n " Indique e-mail para recibir alertas: "; read inbox
    apt-get install libapache2-mod-evasive
    mkdir /var/log/mod_evasive
    chown www-data:www-data /var/log/mod_evasive/
    sed s/MAILTO/$inbox/g templates/mod-evasive > /etc/apache2/mods-available/mod-evasive.conf
    service apache2 restart
    say_done
}


# 17. Configurar fail2ban
function config_fail2ban() {
    write_title "17. Finalizar configuración de fail2ban"
    sed s/MAILTO/$inbox/g templates/fail2ban > /etc/fail2ban/jail.local
    cp /etc/fail2ban/jail.local /etc/fail2ban/jail.conf
    /etc/init.d/fail2ban restart
    say_done
}


# 18. Instalación de paquetes adicionales
function install_aditional_packages() {
    write_title "18. Instalación de paquetes adicionales"
    echo "18.1. Instalar Bazaar..........."; apt-get install bzr
    echo "18.2. Instalar tree............."; apt-get install tree
    echo "18.3. Instalar Python-MySQLdb..."; apt-get install python-mysqldb
    echo "18.4. Instalar WSGI............."; apt-get install libapache2-mod-wsgi
    echo "18.5. Instalar PIP.............."; apt-get install python-pip
    echo "18.6. Instalar Vim.............."; apt-get install vim
    echo "18.7. Instalar Nano............."; apt-get install nano
    echo "18.8. Instalar pear............."; apt-get install php-pear
    echo "18.9. Instalar PHPUnit..........";
    pear config-set auto_discover 1
    mv phpunit-patched /usr/share/phpunit
    echo include_path = ".:/usr/share/phpunit:/usr/share/phpunit/PHPUnit" >> /etc/php5/apache2/php.ini
    service apache2 restart
    say_done
}

# 19. Tunear y Asegurar Kernel
function tunning_kernel() {
    write_title "19. Tunear Kernel"
    cp templates/sysctl.conf /etc/sysctl.conf; echo " OK"
    sysctl -e -p
    say_done
}

# 20. Tunnear el archivo .bashrc
function tunning_bashrc() {
    write_title "20. Reemplazar .bashrc"
    cp templates/bashrc-root /root/.bashrc
    cp templates/bashrc-user /home/$username/.bashrc
    chown $username:$username /home/$username/.bashrc
    say_done
}


# 21. Tunnear Vim
function tunning_vim() {
    write_title "21. Tunnear Vim"
    tunning vimrc
}


# 22. Tunnear Nano
function tunning_nano() {
    write_title "22. Tunnear Nano"
    tunning nanorc
}


# 23. Agregar tarea de actualización diaria
function add_updating_task() {
    write_title "23. Agregar tarea de actualización diaria al Cron"
    tarea="@daily apt-get update; apt-get dist-upgrade -y"
    touch tareas
    echo $tarea >> tareas
    crontab tareas
    rm tareas
    say_done
}


# 24. Agregar comandos personalizados
function add_commands() {
    write_title "24. Agregar comandos personalizados"
    add_command_blockip     # Agregar regla bloqueo a iptables
    say_done
}


# 25. Instalar PortSentry
function install_portsentry() {
    write_title "# 25. Instalar y configurar el antiscan de puertos PortSentry"
    apt-get install portsentry
    mv /etc/portsentry/portsentry.conf /etc/portsentry/portsentry.conf-original
    cp templates/portsentry /etc/portsentry/portsentry.conf
    sed s/tcp/atcp/g /etc/default/portsentry > salida.tmp
    mv salida.tmp /etc/default/portsentry
    /etc/init.d/portsentry restart
    say_done
}


# 26. Reiniciar servidor
function final_step() {
    write_title "26. Finalizar deploy"
    replace USERNAME $username SERVERIP $serverip < templates/texts/bye
    echo -n " ¿Ha podido conectarse por SHH como $username? (y/n) "
    read respuesta
    if [ "$respuesta" == "y" ]; then
        reboot
    else
        echo "El servidor NO será reiniciado y su conexión permanecerá abierta."
        echo "Bye."
    fi
}


is_root_user                    #  0. Verificar si es usuario root o no
set_hostname                    #  1. Configurar Hostname
set_hour                        #  2. Configurar zona horaria
sysupdate                       #  3. Actualizar el sistema
set_new_user                    #  4. Crear un nuevo usuario con privilegios
give_instructions               #  5. Instrucciones para generar una RSA Key
move_rsa                        #  6. Mover la llave pública RSA generada
ssh_reconfigure                 #  7. Securizar SSH
set_iptables_rules              #  8. Establecer reglas para iptables
create_iptable_script           #  9. Crear script de automatizacion iptables
install_fail2ban                # 10. Instalar fail2ban
install_mysql                   # 11. Instalar, Configurar y Optimizar MySQL
install_php                     # 12. Instalar, configurar y optimizar PHP
install_modsecurity             # 13. Instalar ModSecurity
install_owasp_core_rule_set     # 14. Instalar OWASP para ModSecuity
configure_apache                # 15. Configurar y optimizar Apache
install_modevasive              # 16. Instalar ModEvasive
config_fail2ban                 # 17. Configurar fail2ban
install_aditional_packages      # 18. Instalación de paquetes adicionales
tunning_kernel                  # 19. Asegurar Kernel
tunning_bashrc                  # 20. Tunnear el archivo .bashrc
tunning_vim                     # 21. Tunnear Vim
tunning_nano                    # 22. Tunnear Nano
add_updating_task               # 23. Agregar tarea de actualización diaria
add_commands                    # 24. Agregar comandos personalizados
install_portsentry              # 25. Instalar PortSentry
final_step                      # 26. Reiniciar servidor

