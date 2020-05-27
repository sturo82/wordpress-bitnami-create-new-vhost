read -p "Enter Your domain: "  DOMAIN
read -p "Enter Your contact email: "  EMAIL

if [  -z "$DOMAIN" ] || [  -z "$EMAIL" ]
  then
    echo 'Parametri obbligatori mancanti'
    ./$(basename $0) && exit
fi

sudo /opt/bitnami/ctlscript.sh stop
sudo /opt/bitnami/letsencrypt/lego --tls --email="EMAIL" --domains="$DOMAIN" --path="/opt/bitnami/letsencrypt" run
sudo /opt/bitnami/ctlscript.sh start