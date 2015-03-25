#!/bin/sh

## Check for root and docker and required files

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
command -v docker >/dev/null 2>&1 || { echo >&2 "This script requires docker. Please install it first."; exit 1; }
if [ ! -f "Dockerfile" ]; then echo "Dockerfile missing";exit 1;fi

## Create setpassword script

echo '#!/bin/bash'>setpassword.sh
echo 'source /couchdb.cfg'>>setpassword.sh
echo 'couchdb -b && sleep 3 && curl -X PUT http://127.0.0.1:5984/_config/admins/$couch_username -d \""$couch_password"\"  && couchdb -d' >>setpassword.sh

## Switch for non-interactive modes

case "$#" in

## 5 Params: user password imagetag containername dbport

"5")imgtag="$3"
	name="$4"
	port="$5"
	;&

## 2 Params: user password

"2")user="$1"
	password="$2"
	password_conf="$2"
	;;
## Interactive

"0")echo CouchDB for Docker setup
	echo
	echo "for non-interactive, use ./setup.sh user password [imagetag containername dbport]"
	echo
	echo "Do not use blanks or not URL-safe characters!"
	echo
	echo "Enter a CouchDB administrator username"
	read user
	echo "Enter a CouchDB administrator password (will not be shown)"
	read -s password
	echo "Confirm CouchDB administrator password (will not be shown)"
	read -s password_conf
	;;
esac

## Check for matching passwords

if [ "$password_conf" == "$password" ]; then
	echo "Passwords match, proceeding..." 
	echo couch_username=\""$user"\">couchdb.cfg
	echo couch_password=\""$password"\">>couchdb.cfg
	echo
	echo "*** Building Docker image $imgtag ***"
	echo
		
	## Check for set varibles (and fallback to interactive)

	if [ -z "$imgtag" ]; then
		echo "Enter a Docker image tag or press [ENTER] to use default (docker/couchdb)"
		read customimgtag
		[ ! -z "$customimgtag" ] && imgtag="$customimgtag" || imgtag="docker/couchdb"
	fi

	if [ -z "$name" ]; then
		echo "Enter a Docker container name  or press [ENTER] to use default (couchdb)"
		read customname
		[ ! -z "$customname" ] && name="$customname" || name="couchdb"
	fi

	if [ -z "$port" ]; then
		echo "Enter a free TCP port for https access to CouchDB or press [ENTER] to use default (6984)"
		read customport
		[ ! -z "$customport" ] && port="$customport" || port="6984"
	fi
		
	## Build image

    docker build -t="$imgtag" .
		
	## Start container		
		
    docker run -d -p "$port":6984 --name="$name" "$imgtag"
		
	## Create startup, shutdown and clean scripts
	
	echo "docker run $name" > startCouch.sh
	chmod 755 startCouch.sh
	echo "docker stop -t 3 $name" > stopCouch.sh
	chmod 755 stopCouch.sh
	echo "docker stop -t 1 $name;docker rm $name;docker rmi $imgtag;rm stopCouch.sh;rm removeCouch.sh" > removeCouch.sh
	chmod 755 removeCouch.sh
	echo
	echo "CouchDB is up and running, to stop, call stopCouch.sh; to start, call startCouch.sh; to remove, call removeCouch.sh"
	
else
	echo "Passwords did not match, exiting..."
	exit 1
fi

## Final cleanup

rm setpassword.sh
rm couchdb.cfg