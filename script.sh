#!/bin/bash

#docker_installation
if [ ! -x /var/lib/docker ]; then
    echo "Installing docker"
    apt install apt-transport-https ca-certificates curl software-properties-common -y
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"	
	apt update -y
	apt-cache policy docker-ce 
	apt install docker-ce -y 
	usermod -aG docker ${USER}
fi

apt install git
git clone https://github.com/bohdanborysovskyi/azuretask.git
cd azuretask
docker build -t app .
docker run -p 80:80 app