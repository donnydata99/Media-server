#!/bin/bash

source ${CONFIGS}/Docker/.env
which rclone > ${CONFIGVARS}/checkrcl.txt
clear

if [ ! -s ${CONFIGVARS}/checkrcl.txt ]; then

	RCLONECHECK

else

	EXPLAINTASK

	CONFIRMATION

	if [[ ${REPLY} =~ ^[Yy]$ ]]; then

		GOAHEAD

		mkdir -p /tmp/goobyrestore
		mkdir -p /tmp/Gooby
		RESTOREFOLDER=/tmp/goobyrestore
		OLDFILES=/tmp/Gooby

		echo " Restoring the backup can take several hours"
		echo " please don't exit the terminal until it's done!"
		echo
		read -e -p " Server to restore: " -i "${SERVER}" SERVER
		echo
		echo " App name to restore: (for example, ${LYELLOW}Docker${STD} or ${LYELLOW}Plex${STD})"
		echo " You can find your app names in ${RCLONESERVICE}:/Backup/${SERVER}/Gooby"
		echo " You can type ${LYELLOW}All${STD} for all Docker apps,"
		echo " Or ${LYELLOW}Home${STD} for restoring your /home/${USER} directory"
		echo
		read -e -p " App to restore (case matters): " -i "All" APPNAME

		echo
		echo " ${LMAGENTA}Copying ${APPNAME} backup from ${RCLONESERVICE}...${STD}"
		echo

		if [ "${APPNAME}" == "Home" ]; then

			/usr/bin/rclone --stats-one-line -P copy ${RCLONESERVICE}:/Backup/${SERVER}/${SERVER}-backup.tar.gz ${RESTOREFOLDER} --checksum --drive-chunk-size=64M

			[ -f ${RESTOREFOLDER}/${SERVER}-backup.tar.gz ] || { echo; echo " ${LRED}Sorry, backup not found on ${RCLONESERVICE}!${STD} - please try again"; PAUSE; exit ;}

			echo
			echo " ${GREEN}Restoring your home folder...${STD}"
			echo

			tar -xpvf ${RESTOREFOLDER}/${SERVER}-backup.tar.gz -C /
			sudo chown ${USER}:${USER} ${HOME}

		else

			if [ "${APPNAME}" == "All" ]; then

				/usr/bin/rclone --stats-one-line -P copy ${RCLONESERVICE}:/Backup/${SERVER}/Gooby ${RESTOREFOLDER} --checksum --drive-chunk-size=64M
				[ -f ${RESTOREFOLDER}/Docker-full.tar.gz ] || { echo; echo " ${LRED}Sorry, backup not found on ${RCLONESERVICE}!${STD} - please try again"; PAUSE; exit ;}
				sudo mv ${CONFIGS}/[^.]* ${OLDFILES}
				sudo rm -f "${CONFIGVARS}/snapshots/*.snar"

			else

				echo "+ ${APPNAME}*" > ${CONFIGVARS}/checkapp.txt
				echo "- *" >> ${CONFIGVARS}/checkapp.txt
				/usr/bin/rclone --stats-one-line -P copy ${RCLONESERVICE}:/Backup/${SERVER}/Gooby --filter-from ${CONFIGVARS}/checkapp.txt ${RESTOREFOLDER} --checksum --drive-chunk-size=64M
				rm -f ${CONFIGVARS}/checkapp.txt
				[ -f ${RESTOREFOLDER}/${APPNAME}-full.tar.gz ] || { echo; echo " ${LRED}Sorry, backup not found on ${RCLONESERVICE}!${STD}, please try again"; PAUSE; exit ;}
				sudo mv ${CONFIGS}/${APPNAME}/ ${OLDFILES}
				sudo rm -f "${CONFIGVARS}/snapshots/${APPNAME}.snar"

			fi

			echo
			echo " ${LBLUE}${APPNAME} backup downloaded, proceeding...${STD}"
			echo

			echo
			echo " ${YELLOW}Taking containers down...${STD}"

			cd ${CONFIGS}/Docker
			/usr/local/bin/docker-compose down
			cd ${CURDIR}

			echo
			echo " ${GREEN}Restoring files...${STD}"
			echo

			cd ${CONFIGS}

			for f in ${RESTOREFOLDER}/*-full.tar.gz

			do

				echo " ${GREEN}Extracting full archive... ${f}${STD}"
				echo
				tar -xpvf "$f"
				echo
				rm "$f"

			done

				for f in ${RESTOREFOLDER}/*-diff.tar.gz

			do

				echo " ${GREEN}Extracting differential archive... ${f}${STD}"
				echo
				[ -f "$f" ] && tar --incremental -xpvf "$f"
				echo
				[ -f "$f" ] && rm "$f"

			done

			cd ${CURDIR}
			mkdir -p ${CONFIGVARS}/snapshots
			source /bin/resetbackup

			echo " ${GREEN}Restoring permissions, please wait...${STD}"
			echo
			sudo chown ${USER}:${USER} ${CONFIGS}

			echo
			echo " ${CYAN}Finished restoring ${APPNAME}${STD}"
			echo

			echo
			echo " ${WHITE}Make sure${STD} you check if your services are"
			echo " running properly before you remove the old installation!"
			echo
			echo " Run ${WHITE}rclean${STD} to bring up all containers again"
			read -n 1 -r -p " Remove old installation files (y/N)? " -i "" CHOICE
			echo

			case "${CHOICE}" in
				y|Y ) sudo rm -r ${OLDFILES} ;;
				* ) echo " Your old installation files are available"; echo " at ${OLDFILES} until you reboot"; echo ;;
			esac

		fi

			sudo rm -r ${RESTOREFOLDER}

		TASKCOMPLETE

	else

		CANCELTHIS

	fi

fi

rm -f ${CONFIGVARS}/checkrcl.txt
PAUSE
