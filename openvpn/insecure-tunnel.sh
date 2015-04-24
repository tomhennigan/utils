#!/bin/bash

# Deploys an OpenVPN server in a docker container.
#
# I have no idea what the key size is or any security settings etc as I have not
# inspected the docker image being deployed. In it's current state you can
# consider this an insecure tunnel via an untrusted machine (much like most of
# the internet) in a location you can control (unlike much of the internet).
#
# I would advise deploying this on a server with nothing else running (I assume
# the docker image is potentially malicious and therefore want to isolate it
# from things I do trust). With a single client the smallest machine from
# Digital Ocean works great.

function checkenv() {
  # Checks whether the given environment variable is set and not empty.
  if [[ -z $(env | egrep "^${1}=.") ]]; then
    echo 2>&1 "error: environment variable $1 must be set and not empty."
    exit 1
  fi
}

function provision() {
	checkenv EXTERNAL_IP

	docker run --name ovpn-data -v /etc/openvpn busybox
	docker run --volumes-from ovpn-data --rm kylemanna/openvpn ovpn_genconfig -u "udp://${EXTERNAL_IP}:1194"
	docker run --volumes-from ovpn-data --rm -it kylemanna/openvpn ovpn_initpki
	cat > /etc/init/docker-openvpn.conf << __EOF
	description "Docker container for OpenVPN server"
	start on filesystem and started docker
	stop on runlevel [!2345]
	respawn
	script
	  exec docker run --volumes-from ovpn-data --rm -p 1194:1194/udp --cap-add=NET_ADMIN kylemanna/openvpn
	end script
	__EOF
	sudo start docker-openvpn
}

function generate_config() {
	checkenv CONFIG_NAME
	checkenv EXTERNAL_IP

	docker run --volumes-from ovpn-data --rm -it kylemanna/openvpn easyrsa build-client-full "${CONFIG_NAME}" nopass
	docker run --volumes-from ovpn-data --rm kylemanna/openvpn ovpn_getclient "${CONFIG_NAME}" > "${CONFIG_NAME}.ovpn"
	
	echo
	echo "To copy this config to your local machine run:"
	echo
	echo "    scp -i <yourkey> root@${EXTERNAL_IP}:${CONFIG_NAME}.ovpn ."
}

if [ ! -e /etc/init/docker-openvpn.conf ]; then
  echo "Provisioning OpenVPN"
	provision
fi

generate_config
