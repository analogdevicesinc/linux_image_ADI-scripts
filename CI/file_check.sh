#!/bin/bash

FILENAME=$1
DEST="\$(DESTDIR)"

while IFS= read -r LINE_VAL; do
	LINE=$(echo $LINE_VAL | xargs)	
	IFS=' '
	read -a COMMAND_ARGUMENTS <<< $LINE
	LENGTH=${#COMMAND_ARGUMENTS[@]}
	case $LINE in
		"DESTDIR="*) #save value of variable DESTDIR
			IFS='='
			read -a DESTDIR_VALUE <<< $LINE
			;;
		"install -d"*)  #creates directory from the PATH given as agrument
			if [[ ! ${COMMAND_ARGUMENTS[$LENGTH-1]} == *"(DESTDIR)"* ]]; then
				if [[ ! -d ${COMMAND_ARGUMENTS[$LENGTH-1]} ]]; then
					echo "Directory ${COMMAND_ARGUMENTS[$LENGTH-1]} DOES NOT exists."
					exit 1
				else
					echo "Directory ${COMMAND_ARGUMENTS[$LENGTH-1]} exists."
				fi
			else
				if [[ ! -d ${COMMAND_ARGUMENTS[$LENGTH-1]/$DEST/${DESTDIR_VALUE[1]}} ]]; then
					echo "Directory ${COMMAND_ARGUMENTS[$LENGTH-1]/$DEST/${DESTDIR_VALUE[1]}} DOES NOT exists."
					exit 1
				else
					echo "Directory ${COMMAND_ARGUMENTS[$LENGTH-1]/$DEST/${DESTDIR_VALUE[1]}} exists."
				fi
			fi
			;;
		"install -D -m"*)  #copy file from specified location to given PATH
			FILE_PATH=${COMMAND_ARGUMENTS[$LENGTH-1]}

			if [[ ${FILE_PATH} == *"/" ]]; then
				IFS='/'
				read -a COPIED_FILE <<< ${COMMAND_ARGUMENTS[$LENGTH-2]}
				LENGTH=${#COPIED_FILE[@]}

				if [[ ! -f $FILE_PATH${COPIED_FILE[$LENGTH-1]} ]]; then
					echo "File $FILE_PATH${COPIED_FILE[$LENGTH-1]} DOES NOT exists"
					exit 1
				else
					echo "File $FILE_PATH${COPIED_FILE[$LENGTH-1]} exists"
				fi
			else
				if [[ ! -f ${FILE_PATH} ]]; then  #if the PATH where to copy ends with a file, the content of the file will be modified with the one we want to copy
					echo "File ${FILE_PATH} DOES NOT exists"
					exit 1
				else
					echo "File ${FILE_PATH} exists"
				fi
			fi
			IFS=''
			;;
		"systemctl enable"*".service"*) #enables sepecified serices as command arguments, but we check the status of those ended in .service
			LENGTH=$(wc -w <<< $LINE)
			NEWLINE=$(cut -d " " -f 3-$LENGTH <<< $LINE)
			IFS=' '
			read -a COMMAND_ARGUMENTS <<< $NEWLINE

			for ARGUMENT in ${COMMAND_ARGUMENTS[@]}; do
				if [[ $ARGUMENT == *".service" ]]; then
					if [[ ! $(sudo systemctl status $ARGUMENT | grep 'Loaded' | grep -q 'enabled') ]]; then
						echo "Service $ARGUMENT is enabled"
					else
						echo "Service $ARGUMENT is NOT enabled"
						exit 1
					fi
				fi
			done
			;;
		*)
			;;
	esac
done < $FILENAME
