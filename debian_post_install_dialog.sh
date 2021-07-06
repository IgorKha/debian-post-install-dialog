#!/bin/bash

set -u

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function ask() {
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


if [[ $EUID -ne 0 ]]; then
   	echo -e "\n${RED}------This script must be run as root------\n${NC}" 
   	exit 1
else
	#Checking apt blocking
	while [[ `ps aux | grep -i apt | wc -l` != 1 ]] ; do
    echo -e "\n${YELLOW}------Wait, apt is locked by another process------\n${NC}"
    sleep 15
    ps aux | grep -i apt | wc -l
	done

	if ask "Update and Upgrade ?" Y; then
		echo -e "\n${YELLOW}------Updating and Upgrading------\n${NC}"
		apt-get update && sudo apt-get upgrade -y
		echo -e "\n${GREEN}------Updating and Upgrading complite------\n${NC}"
	fi


	echo -e "\n${YELLOW}------Check install dialog------\n${NC}"
	RESULT=`dpkg --list dialog >> /dev/null 2>&1 && echo "True" || echo "False"`
	if [[ "$RESULT" == "False" ]]; then
	        if ask "Need install dialog" Y; then
			    apt-get install dialog -y
			else
				echo -e "\n${RED}For correct work you need to install dialog\n${NC}"
				exit 1
			fi
	else
	    echo -e "\n${GREEN}------Already installed dialog------\n${NC}"
	fi

	RESULT=`dpkg --list software-properties-common >> /dev/null 2>&1 && echo "True" || echo "False"`
	if [[ "$RESULT" == "False" ]]; then
	        if ask "Need install software-properties-common" Y; then
			    apt-get install software-properties-common -y
			else
				echo -e "\n${RED}For correct work you need to install software-properties-common\n${NC}"
				# exit 1
			fi
	else
	    echo -e "\n${GREEN}------Already installed software-properties-common------\n${NC}"
	fi

	cmd=(dialog --separate-output --checklist "Please Select Software you want to install:" 22 76 16)
	options=(1 "Git" off   # any option can be set to default to "on"
		)
		choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
		clear
		for choice in $choices
		do
		    case $choice in
	        1)
				echo -e "\n${YELLOW}------Installing Git $(apt show git | grep "Version"))------\n${NC}"
				apt install git -y
				echo -e "\n${GREEN}------Installing Git complite------\n${NC}"
				;;
	    esac
	done
fi
