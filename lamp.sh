#!/bin/bash

# Récupération des infos database et futur login wordpress
echo "nom hote database"
read madatabase
echo "nom utilisateur azure maria db"
read username
echo "password utilisateur azure maria db"
read password_here
echo "nom de base de donnée wp"
read database_wp_name_here

sudo apt -y update
# Installation de php
sudo apt -y install php libapache2-mod-php php-mysql
# Installation de Apache
sudo apt -y install apache2
# Install maridb-client
sudo apt -y install mariadb-client


#####################################################################
#                            WORDPRESS                              #
#####################################################################
cd /var/www/html/

sudo wget https://wordpress.org/latest.tar.gz

sudo tar -xvf latest.tar.gz


sudo cp wordpress/wp-config-sample.php wordpress/wp-config.php
sudo chown -R www-data:www-data /var/www/html/wordpress/
cd wordpress/
####################################################
#          config wordpress                        #
####################################################

sudo sed -i "s/database_name_here/$database_wp_name_here/" wp-config.php
sudo sed -i "s/username_here/$username/" wp-config.php
sudo sed -i "s/password_here/$password/" wp-config.php
sudo sed -i "s/localhost/$madatabase/" wp-config.php

sudo chmod u-w wp-config.php

sudo systemctl restart apache2

###config mariadb saas de wordpress

#creation fichier instruction sql 

sudo echo "CREATE DATABASE IF NOT EXISTS $database_wp_name_here default character set utf8 collate utf8_unicode_ci;" > instructionsql.sql

#connexion mariadb-client avec password et injection de nos instruction liée a wordpress
sudo mariadb --user=$username --password=$password_here --host=$madatabase < instructionsql.sql > output.tab

# sudo mariadb --user=mdbg1admin1 --password=Adminpass1 --host=mariadbsaasdatabasee.mariadb.database.azure.com < instructionsql.sql > output.tab
# creation de wordpressdb et utilisateur si elle n'existe pas
# CREATE DATABASE IF NOT EXISTS $database_wp_name_here default character set utf8 collate utf8_unicode_ci;
# CREATE USER IF NOT EXISTS '$username_wp'@'$database_wp_name_here' IDENTIFIED BY '$password_wp';
# GRANT ALL on $database_wp_name_here.* to '$username_wp'@'$database_wp_name_here' identified by '$password_wp';
# flush privileges;
# exit;





