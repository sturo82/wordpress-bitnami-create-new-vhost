#!/bin/bash

while getopts ":d:n:b:" opt; do
  case $opt in
    d) DOMAIN="$OPTARG"
    ;;
    n) APPNAME="$OPTARG"
    ;;
    b) DBNAME="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

if [ -z "$DBNAME" ]
  then
    echo "DBNAME is empty"
    DBNAME=$APPNAME"_db"
fi


read -p "DBNAME is set to $DBNAME APPNAME is set to $APPNAME DOMAIN is set to $DOMAIN. Continue?(y/n)" -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    #Create fresh wp installation with copy of default bitnami vhost
sudo mkdir -p /opt/bitnami/apps/$APPNAME && sudo rsync -av /opt/bitnami/apps/wordpress/ /opt/bitnami/apps/$APPNAME
sudo rm -r /opt/bitnami/apps/$APPNAME/htdocs/*
cd /opt/bitnami/apps/$APPNAME/htdocs/
wget http://wordpress.org/latest.tar.gz
tar xfz latest.tar.gz
sudo mv /opt/bitnami/apps/$APPNAME/htdocs/wordpress/* /opt/bitnami/apps/$APPNAME/htdocs/
sudo rmdir /opt/bitnami/apps/$APPNAME/htdocs/wordpress/
sudo rm -f /opt/bitnami/apps/$APPNAME/htdocs/latest.tar.gz

#stop services
sudo /opt/bitnami/ctlscript.sh stop

#creo i file all'interno della cartella app per vhost
cat <<EOF >/opt/bitnami/apps/$APPNAME/conf/htaccess.conf
<Directory "/opt/bitnami/apps/$APPNAME/htdocs/wp-content/plugins/akismet">
# Only allow direct access to specific Web-available files.

# Apache 2.2
<IfModule !mod_authz_core.c>
        Order Deny,Allow
        Deny from all
</IfModule>

# Apache 2.4
<IfModule mod_authz_core.c>
        Require all denied
</IfModule>

# Akismet CSS and JS
<FilesMatch "^(form\.js|akismet\.js|akismet\.css)$">
        <IfModule !mod_authz_core.c>
                Allow from all
        </IfModule>

        <IfModule mod_authz_core.c>
                Require all granted
        </IfModule>
</FilesMatch>

# Akismet images
<FilesMatch "^logo-full-2x\.png$">
        <IfModule !mod_authz_core.c>
                Allow from all
        </IfModule>

        <IfModule mod_authz_core.c>
                Require all granted
        </IfModule>
</FilesMatch>
</Directory>
EOF




cat <<EOF >/opt/bitnami/apps/$APPNAME/conf/httpd-app.conf
RewriteEngine On
RewriteRule /<none> / [L,R]

<IfDefine USE_PHP_FPM>
    <Proxy "unix:/opt/bitnami/php/var/run/wordpress.sock|fcgi://wordpress-fpm" timeout=300>
    </Proxy>
</IfDefine>

<Directory "/opt/bitnami/apps/$APPNAME/htdocs">
    Options +MultiViews +FollowSymLinks
    AllowOverride None
    <IfVersion < 2.3 >
        Order allow,deny
        Allow from all
    </IfVersion>
    <IfVersion >= 2.3>
        Require all granted
    </IfVersion>


    <IfModule php7_module>
            php_value memory_limit 512M
    </IfModule>

    <IfDefine USE_PHP_FPM>
       <FilesMatch \.php$>
         SetHandler "proxy:fcgi://wordpress-fpm"
       </FilesMatch>
    </IfDefine>


    RewriteEngine On
    #RewriteBase /$APPNAME/
    RewriteRule ^index\.php$ - [S=1]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule . index.php [L]

    #Include "/opt/bitnami/apps/$APPNAME/conf/banner.conf"
</Directory>

Include "/opt/bitnami/apps/$APPNAME/conf/htaccess.conf"
EOF

cat <<EOF >/opt/bitnami/apps/$APPNAME/conf/httpd-prefix.conf
# App url moved to root
DocumentRoot "/opt/bitnami/apps/$APPNAME/htdocs"
    #Alias /$APPNAME/ "/opt/bitnami/apps/$APPNAME/htdocs/"
#Alias /$APPNAME "/opt/bitnami/apps/$APPNAME/htdocs"

RewriteEngine On
RewriteCond "%{HTTP_HOST}" ^ec2-([0-9]{1,3})-([0-9]{1,3})-([0-9]{1,3})-([0-9]{1,3})\..*\.amazonaws.com(:[0-9]*)?$
RewriteRule "^/?(.*)" "%{REQUEST_SCHEME}://%1.%2.%3.%4%5/$1" [L,R=302,NE]

Include "/opt/bitnami/apps/$APPNAME/conf/httpd-app.conf"
EOF



cat <<EOF >/opt/bitnami/apps/$APPNAME/conf/httpd-vhosts.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot "/opt/bitnami/apps/$APPNAME/htdocs"

    Include "/opt/bitnami/apps/$APPNAME/conf/httpd-app.conf"
</VirtualHost>

<VirtualHost *:443>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot "/opt/bitnami/apps/$APPNAME/htdocs"
    SSLEngine on
    SSLCertificateFile "/opt/bitnami/letsencrypt/certificates/$DOMAIN.crt"
    SSLCertificateKeyFile "/opt/bitnami/letsencrypt/certificates/$DOMAIN.key"

    Include "/opt/bitnami/apps/$APPNAME/conf/httpd-app.conf"
</VirtualHost>
EOF


#obtaining certificates
sudo /opt/bitnami/letsencrypt/lego --tls --email="dev@endurancecloud.com" --domains="$DOMAIN" --path="/opt/bitnami/letsencrypt" run

#start services
sudo /opt/bitnami/ctlscript.sh start

#creare nuovo db 
dbrootusername='root'
sudo cat /home/bitnami/bitnami_credentials
echo "Type password of db [ENTER]:"
read dbrootpassword
mysql -u $dbrootusername -p $dbrootpassword
#Find bitnami credentials "sudo cat /home/bitnami/bitnami_credentials"
vhostUser='vhusr_'$APPNAME
vhostPassword='xDgTrfVu_'$APPNAME

create user $vhostUser@'localhost' identified by $vhostPassword;
create database $DBNAME;
grant usage on *.* to $vhostUser@'localhost' identified by $vhostPassword;
grant all privileges on $DBNAME.* to $vhostPassword@localhost;

#test f db is correctly created
#use dbname;
exit;

#abilitare vhost appena creato in /opt/bitnami/apache2/conf/bitnami/bitnami-apps-vhosts.conf
echo "Include \"/opt/bitnami/apps/$APPNAME/conf/httpd-vhosts.conf\"" >>  /opt/bitnami/apache2/conf/bitnami/bitnami-apps-vhosts.conf
#go to website and finish installation via browser

#uncomment on /opt/bitnami/apache2/conf/httpd.conf Include conf/extra/httpd-vhosts.conf
line="Include conf\/extra\/httpd-vhosts.conf"
filename="/opt/bitnami/apache2/conf/httpd.conf"
#uncomment:
sudo sed -i "/${line}/ s/# *//" $filename

#to comment it out:
#sed -i "/${line}/ s/^/# /" $filename 

sudo /opt/bitnami/ctlscript.sh restart apache
else
 echo "hai rifiutato"
fi




