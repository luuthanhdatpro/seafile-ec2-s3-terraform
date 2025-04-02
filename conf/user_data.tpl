#!/bin/bash
	
echo  "Install dependencies"
apt-get update
apt-get install -y python3 python3-dev python3-setuptools python3-pip libmysqlclient-dev ldap-utils libldap2-dev python3.12-venv
apt-get install -y memcached libmemcached-dev mariadb-server s3fs nginx
	
# python3 -m venv python-venv
# source python-venv/bin/activate
	
pip3 install --timeout=3600 django==4.2.* future==0.18.* mysqlclient==2.1.* \
	pymysql pillow==10.2.* pylibmc captcha==0.5.* markupsafe==2.0.1 jinja2 sqlalchemy==2.0.18 \
	psd-tools django-pylibmc django_simple_captcha==0.6.* djangosaml2==1.5.* pysaml2==7.2.* pycryptodome==3.16.* cffi==1.16.0 lxml python-ldap==3.4.3

echo  "MariaDB setup:"
	# - perform steps from mysql_secure_installation: Set root password, delete anonymous users, disable remote login for root, remove test database
	# - create Seafile databases and user
systemctl start mariadb
systemctl enable mariadb
mysql -u root -e "\
		ALTER USER 'root'@'localhost' IDENTIFIED BY 'my_very_secure_password_1'; \
		DELETE FROM mysql.user WHERE User=''; \
		DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'); \
		DROP DATABASE IF EXISTS test; \
		DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'; \
		CREATE DATABASE ccnet_db CHARACTER SET = 'utf8'; \
		CREATE DATABASE seafile_db CHARACTER SET = 'utf8'; \
		CREATE DATABASE seahub_db CHARACTER SET = 'utf8'; \
		CREATE USER 'seafile'@'localhost' IDENTIFIED BY 'my_very_secure_password_2'; \
		GRANT ALL PRIVILEGES ON \`ccnet_db\`.* TO seafile@localhost; \
		GRANT ALL PRIVILEGES ON \`seafile_db\`.* TO seafile@localhost; \
		GRANT ALL PRIVILEGES ON \`seahub_db\`.* TO seafile@localhost; \
		FLUSH PRIVILEGES;"

echo   "Create s3fs mount point"
mkdir /data

echo  "Install Seafile"
mkdir /usr/share/nginx/html/seafile && cd $_
wget ${download_url}
tar -xzf seafile-server*.tar.gz && rm $_
cd seafile-server*
${template_file}
rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
ln -s /etc/nginx/sites-available/seafile.conf /etc/nginx/sites-enabled/seafile.conf
/usr/share/nginx/html/seafile/seafile-server*/setup-seafile-mysql.sh auto -i 127.0.0.1 -p 8082 -d /data/${bucket_name} -e 1 -u seafile -w ${mysql_seafile_password} -c ccnet_db -s seafile_db -b seahub_db
sed -i "s#SERVICE_URL.*#SERVICE_URL = http://${dns_record}/seafile#" /usr/share/nginx/html/seafile/conf/ccnet.conf
printf "FILE_SERVER_ROOT = 'http://${dns_record}/seafhttp'\nSERVE_STATIC = False\nMEDIA_URL = '/seafmedia/'\nSITE_ROOT = '/seafile/'\nLOGIN_URL = '/seafile/accounts/login/'\nCOMPRESS_URL = MEDIA_URL\nSTATIC_URL = MEDIA_URL + 'assets/'" >> /usr/share/nginx/html/seafile/conf/seahub_settings.py

echo "Set seafile-data directoy to s3fs mount point"
ln -s /data/${bucket_name} /usr/share/nginx/html/seafile/seafile-data

echo "Copy local files to server"
# ${template_file}

echo "Set host name in nginx config"
sed -i "s/#HOSTNAME#/127.0.0.1/g" /etc/nginx/conf.d/seafile.conf

# Load new service files, start Seafile
systemctl daemon-reload
systemctl start seafile
systemctl enable seafile

# Set up Seahub admin on first start (set "password" flag to "false" in check_init_admin script before, so that credentials can be piped in)
sed -i "s/password=True/password=False/g" /usr/share/nginx/html/seafile/seafile-server-latest/check_init_admin.py
printf "${seahub_email}\n${seahub_password}\n${seahub_password}\n" | /usr/share/nginx/html/seafile/seafile-server-latest/seahub.sh start

# Start Seahub and nginx using the service files
/usr/share/nginx/html/seafile/seafile-server-latest/seahub.sh stop
systemctl start seahub
systemctl enable seahub
systemctl start nginx
systemctl enable nginx

# Mount S3 bucket and create basic fs structure
s3fs -o iam_role=${aws_iam_role} -o url=${s3fs_endpoint_url} -o nonempty -o enable_noobj_cache -o ensure_diskfree=1024 -o use_cache=/tmp/s3fs -o noatime ${bucket_name} /data/${bucket_name}
mkdir -p /data/${bucket_name}/tmpfiles /data/${bucket_name}/httptemp/cluster-shared /data/${bucket_name}/storage/blocks

# Exclude s3fs from updatedb indexing
sed -i 's/PRUNEPATHS = "/\PRUNEPATHS = "\/data /g; s/PRUNEFS = "/PRUNEFS = "fuse.s3fs /g' /etc/updatedb.conf

# Mount bucket on start-up
echo 's3fs#${bucket_name} /data/${bucket_name} fuse _netdev,iam_role=${aws_iam_role},url=${s3fs_endpoint_url},nonempty,enable_noobj_cache,ensure_diskfree=1024,use_cache=/tmp/s3fs,noatime 0 0' >> /etc/fstab