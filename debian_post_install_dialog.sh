#!/bin/bash

set -u

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'  
NC='\033[0m' # No Color

base_software=(dialog wget curl) #software-properties-common)

ask() {
    local prompt default reply

    if [[ ${2:-} = 'Y' ]]; then
        prompt='Y/n'
        default='Y'
    elif [[ ${2:-} = 'N' ]]; then
        prompt='y/N'
        default='N'
    else
        prompt='y/n'
        default=''
    fi

    while true; do

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n "$1 [$prompt] "

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read -r reply </dev/tty

        # Default?
        if [[ -z $reply ]]; then
            reply=$default
        fi

        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac
    done
}

check_base_software() {
	local list=$@
	for item in ${list[@]}
	do
		echo -e "\n${YELLOW}======Check install [$item]======\n${NC}"
		dpkg --list $item >> /dev/null 2>&1
		if [[ $? -eq 1 ]]; then
			if ask "Need install [$item]" Y; then
				apt-get install $item -y
				echo -e "\n${GREEN}======Installing [$item] complite======\n${NC}"
			else
				echo -e "\n${RED}For correct work you need to install [$item]\n${NC}"
				exit 1
			fi
		else
			echo -e "\n${GREEN}======Already installed [$item]======\n${NC}"
		fi
	done
}

install() {
	local list=$@
	for item in ${list[@]}
	do
		dpkg --list $item >> /dev/null 2>&1
		if [[ $? -eq 1 ]]; then
				apt-get install $item -y
				echo -e "\n${GREEN}======Installing ${YELLOW}[$item] ${GREEN}[$(dpkg -s $item | grep '^Version:')] complite======\n${NC}"
		else
			echo -e "\n${GREEN}======${YELLOW}[$item] ${GREEN}already installed [$(dpkg -s $item | grep '^Version:')]======\n${NC}"
		fi
	done
}

menu() {
	local list=$@
	for item in ${list[@]}
	do
		dpkg --list $item >> /dev/null 2>&1
		if [[ $? -eq 1 ]]; then
				echo -e "$item [$(dpkg -s $item | grep '^Version:')] complite======\n${NC}"
		else
			echo -e "$item"
		fi
	done
}


if [[ $EUID -ne 0 ]]; then
   	echo -e "\n${RED}======This script must be run as root======\n${NC}" 
   	exit 1
else
	#Checking apt blocking
	while [[ `ps aux | grep -i apt | wc -l` != 1 ]] ; do
    echo -e "\n${YELLOW}======Wait, apt is locked by another process======\n${NC}"
    sleep 15
	done
	echo -e "\n${GREEN}======apt unblocked======\n${NC}"

	if ask "Update and Upgrade ?" Y; then
		echo -e "\n${YELLOW}======Updating and Upgrading======\n${NC}"
		apt-get update && sudo apt-get upgrade -y
		echo -e "\n${GREEN}======Updating and Upgrading complite======\n${NC}"
	fi

	check_base_software ${base_software[@]}

	cmd=(dialog --separate-output --checklist "Please Select Software you want to install:" 22 76 16)
	options=(1 "Git" off # any option can be set to default to "on"
			 2 "mc htop net-tools" off
			 3 "Docker" off
			 4 "Docker-compose" off
			 5 "Jenkins (openjdk-11-jdk included install)" off
		)
		choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
		clear
		for choice in $choices
		do
		    case $choice in
	        1)
				install git
				;;
			2)
				list2=(mc htop net-tools)
				install ${list2[@]}
				;;
			3)	
				wget -qO- https://get.docker.com/ | sh
				# list3=(apt-transport-https \
				# 	ca-certificates \
				# 	curl \
				# 	gnupg \
				# 	lsb-release)
				# install ${list3[@]}
				# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
				# echo \
  		# 		"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  		# 		$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  		# 		apt-get update >> /dev/null 2>&1
  		# 		list3_2=(docker-ce docker-ce-cli containerd.io)
  		# 		install ${list3_2[@]}
				;;
			4)
				COMPOSE_VERSION=`git ls-remote https://github.com/docker/compose | grep refs/tags | grep -oE "[0-9]+\.[0-9][0-9]+\.[0-9]+$" | sort --version-sort | tail -n 1`
				# curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
				sudo sh -c "curl -L https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
				sudo chmod +x /usr/local/bin/docker-compose
				sudo docker-compose --version
				;;

			5)
				list4=(openjdk-11-jdk jenkins)
				wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
				sh -c "echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list"
				apt-get update >> /dev/null 2>&1
				install ${list4[@]}

				systemctl daemon-reload
				systemctl start jenkins
				systemctl status jenkins
				echo -e "${YELLOW}Browse to ${BLUE}http://localhost:8080 ${YELLOW}(or whichever port you configured for Jenkins when installing it) and wait until the Unlock Jenkins page appears.${NC}"
				;;
	    esac
	done
fi
