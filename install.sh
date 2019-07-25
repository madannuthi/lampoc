#!/bin/bash
# Deploys a simple Apache webpage with kittens as a service.

cd /tmp
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - > /dev/null 2>&1
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list > /dev/null 2>&1
apt-get -y update > /dev/null 2>&1
apt-get -y install mssql-tools 2>&1
apt-get -y install unixodbc-dev 2>&1
ln -sfn /opt/mssql-tools/bin/sqlcmd /usr/bin/sqlcmd
apt install -y apache2 > /dev/null 2>&1

cat << EOM > /var/www/html/index.html
<html>
  <head><title>Meow!</title></head>
  <body style="background-image: linear-gradient(red,orange,yellow,green,blue,indigo,violet);">
  <center><img src="http://placekitten.com/800/600"></img></center>
  <marquee><h1>Meow World</h1></marquee>
  </body>
</html>
EOM

echo "Your demo is now ready."