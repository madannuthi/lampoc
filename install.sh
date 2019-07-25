#!/bin/bash
# Deploys a simple Apache webpage with kittens as a service.

cd /tmp
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - > /dev/null 2>&1
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list > /dev/null 2>&1
apt-get -y update > /dev/null 2>&1
apt-get -y install unixodbc-dev 2>&1
ln -sfn /opt/mssql-tools/bin/sqlcmd /usr/bin/sqlcmd
apt install -y apache2 > /dev/null 2>&1

cat << EOM > /var/www/html/index.nginx-debian.html
	<!DOCTYPE html>
	<html>
	<head>
	<title>Welcome to nginx!</title>
	<style>
		body {
			width: 35em;
			margin: 0 auto;
			font-family: Tahoma, Verdana, Arial, sans-serif;
		}
	</style>
	</head>
	<body>
	<h1>Welcome to LAM Terraform POC in Azure!</h1>
	<p>If you see this page, the nginx web server is successfully installed and
	working. Further configuration is required.</p>

	<p>For online documentation and support please refer to
	<a href="http://nginx.org/">nginx.org</a>.<br/>
	Commercial support is available at
	<a href="http://nginx.com/">nginx.com</a>.</p>

	<p><em>Thank you for using nginx.</em></p>
	</body>
	<body style="background-image: linear-gradient(red,orange,yellow,green,blue,indigo,violet);">
	 <center><img src="https://eplexity.com/wp-content/uploads/2018/06/Blog2-2-532x266.png"></img></center>
	  <marquee><h1>Welcome to Lam POC</h1></marquee>
	</body>
	</html>		
EOM

echo "Your demo is now ready."
