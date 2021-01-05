#!/bin/bash

#GLOBAL SETTINGS
declare -ir G_ZPOOL_LIST_PARAMS_COUNT=11
declare -r G_USER=$(users)

declare G_DEVS
declare -a G_DEVS_ARRAY
declare -i G_DEVS_ARRAY_LENGHT
declare G_RAID_TYPE
declare G_POOL_NAME
declare G_FUNC_RESULT

#Function provides dialog width depends on terminal width
function GetDialogWidth(){
	local -i cols=$(( $(tput cols) - 6 ))
	echo  $cols
}

#Function provides dialog to select zfs pool
function SelectPoolFunc() {
	RESULT=""
	local -a POOLS_INFO_ARRAY=($(zpool list -Hp | sort))
	local -i POOLS_COUNT=$(( ${#POOLS_INFO_ARRAY[@]} / $G_ZPOOL_LIST_PARAMS_COUNT ))
	local -i CHECK_LIST_HEIGHT=$(( 7 + $POOLS_COUNT))
	if [[ $CHECK_LIST_HEIGHT -eq 0 ]]; then
		whiptail --title  "ZFS-Bash-GUI" --msgbox  "There are no pools exists." 10 $(GetDialogWidth)
		echo "FUNC_ERROR"
	else
		for (( i = 0; i < $POOLS_COUNT; i++ )); do
			param_offset=$(( $i *  G_ZPOOL_LIST_PARAMS_COUNT ))
			pool_name=${POOLS_INFO_ARRAY[$(( 0 + $param_offset ))]}
			#pool_size=${POOLS_INFO_ARRAY[$(( 1 + $param_offset ))]}
			#pool_alloc=${POOLS_INFO_ARRAY[$(( 2 + $param_offset ))]}
			#pool_free=${POOLS_INFO_ARRAY[$(( 3 + $param_offset ))]}
			#pool_health=${POOLS_INFO_ARRAY[$(( 9 + $param_offset ))]}
			if [[ -z $CHECK_LIST_OPTS ]]; then
				CHECK_LIST_OPTS="$pool_name,$pool_name,on"
			else
				CHECK_LIST_OPTS="$CHECK_LIST_OPTS,$pool_name,$pool_name,off"
			fi
		done

		local -a CHECK_LIST_OPTS_ARAY
		readarray -td, CHECK_LIST_OPTS_ARAY<<<"$CHECK_LIST_OPTS" 
		RESULT=$(whiptail --title "ZFS-Bash-GUI" \
		--radiolist --notags \
		"Select pool:" \
		$CHECK_LIST_HEIGHT $(GetDialogWidth) $POOLS_COUNT \
		${CHECK_LIST_OPTS_ARAY[@]} 3>&1 1>&2 2>&3)

		#If RESULT is local then exitstatus always equals 1
		local exitstatus=$?
		if [ $exitstatus = 0 ];  then
			echo "$RESULT"
		else
	     	echo "DIALOG_CANCEL"
		fi
	fi
}

#Function provides dialog to select disks.
#Return string contains selected disk devices
#Example return: "sda" "sdb" "sdc"
function SelectDevicesFunc() {
	RESULT=""
	local -ra DEVS_ARRAY=($(ls /dev/ | egrep 'sd.$|hd.$|vd.$' | sort))
	local CHECK_LIST_OPTS
	for dev in ${DEVS_ARRAY[@]}; do
		if [[ -z $CHECK_LIST_OPTS ]]; then
			CHECK_LIST_OPTS="/dev/$dev,/dev/$dev,off"
		else
			CHECK_LIST_OPTS="$CHECK_LIST_OPTS,/dev/$dev,/dev/$dev,off"
		fi
	done
	local -a CHECK_LIST_OPTS_ARAY
	readarray -td, CHECK_LIST_OPTS_ARAY<<<"$CHECK_LIST_OPTS" 
	local -i CHECK_LIST_HEIGHT=$(( 7 + ${#DEVS_ARRAY[@]}))
	RESULT=$(whiptail --title "ZFS-Bash-GUI" \
	--checklist --notags \
	"Select devices:" \
	$CHECK_LIST_HEIGHT $(GetDialogWidth) ${#DEVS_ARRAY[@]} \
	${CHECK_LIST_OPTS_ARAY[@]} 3>&1 1>&2 2>&3)
	#If RESULT is local then exitstatus always equals 1
	local exitstatus=$?
	if [ $exitstatus = 0 ];  then
		if [[ -z $RESULT ]]; then
			echo "DIALOG_SELECTION_EMPTY"
		else
			echo "$RESULT"
		fi
	else
	     echo "DIALOG_CANCEL"
	fi

}



#Function provides dialog to select RAID type
#Using: SelectRaidTypeFunc $DEVS_ARRAY_LENGHT
#Example return: mirror
function SelectRaidTypeFunc(){
	RESULT=""
	local -i DEVS_ARRAY_LENGHT=$1
	if [[ -z $DEVS_ARRAY_LENGHT ]]; then
		whiptail --title  "ZFS-Bash-GUI" --msgbox  "SelectRaidTypeFunc Error!\n Empty device array" 10 $(GetDialogWidth)
		echo "FUNC_ERROR"
	elif [[ $DEVS_ARRAY_LENGHT -eq 0 ]]; then
		whiptail --title  "ZFS-Bash-GUI" --msgbox  "SelectRaidTypeFunc Error!\n Device array length is zero" 10 $(GetDialogWidth)
		echo "FUNC_ERROR"
	else
		
		local -a RAID_TYPES
		
		if [[ DEVS_ARRAY_LENGHT -ge 1 ]]; then
			RAID_TYPES[0]="stripe"	
		fi
		if [[ DEVS_ARRAY_LENGHT -ge 2 ]]; then
			RAID_TYPES[1]="mirror"
			RAID_TYPES[2]="raidz"
		fi
		if [[ DEVS_ARRAY_LENGHT -ge 3 ]]; then
			RAID_TYPES[3]="raidz2"
		fi
		if [[ DEVS_ARRAY_LENGHT -ge 4 ]]; then
			RAID_TYPES[4]="raidz3"
		fi

		local -i CHECK_LIST_HEIGHT=$(( 7 + $DEVS_ARRAY_LENGHT))

		for type in ${RAID_TYPES[@]}; do
			if [[ -z $CHECK_LIST_OPTS ]]; then
				CHECK_LIST_OPTS="$type,$type,on"
			else
				CHECK_LIST_OPTS="$CHECK_LIST_OPTS,$type,$type,off"
			fi
		done
		local -a CHECK_LIST_OPTS_ARAY
		readarray -td, CHECK_LIST_OPTS_ARAY<<<"$CHECK_LIST_OPTS" 
		RESULT=$(whiptail --title "ZFS-Bash-GUI" \
		--radiolist --notags \
		"Select pool type:" \
		$CHECK_LIST_HEIGHT $(GetDialogWidth) ${#RAID_TYPES[@]} \
		${CHECK_LIST_OPTS_ARAY[@]} 3>&1 1>&2 2>&3)

		#If RESULT is local then exitstatus always equals 1
		local exitstatus=$?
		if [ $exitstatus = 0 ];  then
			echo "$RESULT"
		else
	     	echo "DIALOG_CANCEL"
		fi
	fi
}



function InputPoolName(){
	RESULT=""
	RESULT=$(whiptail --title  "ZFS-Bash-GUI" --inputbox  "Enter pool name:" 10 $(GetDialogWidth) pool_name 3>&1 1>&2 2>&3)
	local exitstatus=$?
	if [ $exitstatus = 0 ];  then
		if [[ -z $RESULT ]]; then
			echo "DIALOG_INPUT_EMPTY"
		else
			echo $RESULT
		fi
	else
	     echo "DIALOG_CANCEL"
	fi
}


function CreatePoolFunc100() {
	G_FUNC_RESULT=""
	G_DEVS=""
	G_DEVS_ARRAY=()
	G_DEVS_ARRAY_LENGHT=0
	while :; do
		G_DEVS=$(SelectDevicesFunc)
		if [ "$G_DEVS" = "DIALOG_SELECTION_EMPTY" ]; then
			whiptail --title  "ZFS-Bash-GUI" --msgbox  "Error!\nYou must select at least one disk device!" 10 $(GetDialogWidth)
		elif [ "$G_DEVS" = "DIALOG_CANCEL" ]; then
			G_FUNC_RESULT="DIALOG_CANCEL"
			break
		elif [[ "$G_DEVS" != "DIALOG_SELECTION_EMPTY" && "$G_DEVS" != "DIALOG_CANCEL" ]]; then
			break
		else	
			whiptail --title  "ZFS-Bash-GUI" --msgbox  "CreatePoolFunc100 Error!" 10 $(GetDialogWidth)
	    	G_FUNC_RESULT="FUNC_ERROR"
	    	break
		fi
	done
	if [[ "$G_FUNC_RESULT" != "FUNC_ERROR" && "$G_FUNC_RESULT" != "DIALOG_CANCEL" ]]; then
		G_DEVS=${G_DEVS//\"/} #replace '\"' to '' 
		readarray -td, G_DEVS_ARRAY<<<"${G_DEVS// /,}"; #before replace ' ' to ','
		G_DEVS_ARRAY_LENGHT=${#G_DEVS_ARRAY[@]}
		#whiptail --title  "ZFS-Bash-GUI" --msgbox  "Selected $G_DEVS_ARRAY_LENGHT:\n$G_DEVS" 10 $(GetDialogWidth)
	else
		G_DEVS=""
	fi
}



function CreatePoolFunc200() {
	G_FUNC_RESULT=""
	G_RAID_TYPE=""
	G_RAID_TYPE=$(SelectRaidTypeFunc $G_DEVS_ARRAY_LENGHT)
	if [ "$G_RAID_TYPE" = "DIALOG_CANCEL" ]; then
		G_RAID_TYPE=""
		G_FUNC_RESULT="DIALOG_CANCEL"
	elif [ "$G_RAID_TYPE" = "FUNC_ERROR" ]; then
		G_RAID_TYPE=""
		G_FUNC_RESULT="FUNC_ERROR"
	elif [ "$G_RAID_TYPE" = "stripe" ]; then
		G_RAID_TYPE=""
		G_FUNC_RESULT=$G_RAID_TYPE
	else
		G_FUNC_RESULT=$G_RAID_TYPE
	fi
}



function CreatePoolFunc300() {
	G_FUNC_RESULT=""
	G_POOL_NAME=""
	while :; do
		G_POOL_NAME=$(InputPoolName)
		if [ "$G_POOL_NAME" = "DIALOG_INPUT_EMPTY" ]; then
			whiptail --title  "ZFS-Bash-GUI" --msgbox  "Error!\nPool name must not be empty." 10 $(GetDialogWidth)
		elif [ "$G_POOL_NAME" = "DIALOG_CANCEL" ]; then
			G_FUNC_RESULT="DIALOG_CANCEL"
			break
		elif [[ "$G_POOL_NAME" != "DIALOG_INPUT_EMPTY" && "$G_POOL_NAME" != "DIALOG_CANCEL" ]]; then
			break
		else
			whiptail --title  "ZFS-Bash-GUI" --msgbox  "CreatePoolFunc300 Error!" 10 $(GetDialogWidth)
	    	G_FUNC_RESULT="FUNC_ERROR"
	    	break
		fi
	done	

	if [[ "$G_FUNC_RESULT" != "FUNC_ERROR" && "$G_FUNC_RESULT" != "DIALOG_CANCEL" ]]; then
		G_FUNC_RESULT=$G_POOL_NAME
	else
		G_POOL_NAME=""
	fi
}

#Function provides dialogs to create pool
function CreatePoolFunc() {
	local -a FUNC_ARRAY=("CreatePoolFunc100" "CreatePoolFunc200" "CreatePoolFunc300")
	for (( i = 0; i < ${#FUNC_ARRAY[@]}; i++ )); do
		eval ${FUNC_ARRAY[i]}
		if [[ "$G_FUNC_RESULT" = "FUNC_ERROR" ]]; then
			i=$(( $i - 1 ))
		elif [[ "$G_FUNC_RESULT" = "DIALOG_CANCEL" ]]; then
			i=$(( $i - 2 ))
			if [[ i -lt -1 ]]; then
			 	break
			fi
		fi
	done
	if [[ "$G_FUNC_RESULT" != "DIALOG_CANCEL" && "$G_FUNC_RESULT" != "FUNC_ERROR" ]]; then
		local COMMAND="sudo zpool create $G_POOL_NAME $G_RAID_TYPE $G_DEVS 2>zfs-bash-gui.err && sudo chown -R $G_USER:users /$G_POOL_NAME"
		
		if (whiptail --title "ZFS-Bash-GUI" --yes-button "CREATE" --no-button "Cancel" --yesno \
			"Are you sure you want to create pool:
			name - $G_POOL_NAME
			type - $G_RAID_TYPE
			devices - $G_DEVS

			command to execute:
			$COMMAND"\
			20 $(GetDialogWidth));  then
     		eval $COMMAND
			local exitstatus=$?
			if [ $exitstatus = 0 ];  then
				whiptail --title  "ZFS-Bash-GUI" --msgbox "Pool $G_POOL_NAME created successfully!" 10 $(GetDialogWidth)
			else
			    whiptail --title  "ZFS-Bash-GUI" --msgbox "Error while creating pool $G_POOL_NAME!\n\n$(<zfs-bash-gui.err)" 10 $(GetDialogWidth)
			fi
		fi		
	fi
}

function DestroyPoolFunc100() {
	G_FUNC_RESULT=""
	G_POOL_NAME=""
	G_POOL_NAME=$(SelectPoolFunc)
	if [ "$G_POOL_NAME" = "DIALOG_CANCEL" ]; then
		G_POOL_NAME=""
		G_FUNC_RESULT="DIALOG_CANCEL"
	elif [ "$G_POOL_NAME" = "FUNC_ERROR" ]; then
		G_POOL_NAME=""
		G_FUNC_RESULT="FUNC_ERROR"
	else
		G_FUNC_RESULT=$G_POOL_NAME
	fi
}

#Function provides dialogs to destroy pool
function DestroyPoolFunc() {
	local -a FUNC_ARRAY=("DestroyPoolFunc100")
	for (( i = 0; i < ${#FUNC_ARRAY[@]}; i++ )); do
		eval ${FUNC_ARRAY[i]}
		if [[ "$G_FUNC_RESULT" = "FUNC_ERROR" ]]; then
			i=$(( $i - 1 ))
		elif [[ "$G_FUNC_RESULT" = "DIALOG_CANCEL" ]]; then
			i=$(( $i - 2 ))
			if [[ i -lt -1 ]]; then
			 	break
			fi
		fi
	done
	if [[ "$G_FUNC_RESULT" != "DIALOG_CANCEL" && "$G_FUNC_RESULT" != "FUNC_ERROR" ]]; then
		local COMMAND="sudo zpool destroy $G_POOL_NAME 2>zfs-bash-gui.err"
		
		if (whiptail --title "ZFS-Bash-GUI" --yes-button "DESTROY!!!" --no-button "Cancel" --yesno \
			"Are you sure you want to PERMANENTLY DESTROY pool:
			name - $G_POOL_NAME

			command to execute:
			$COMMAND"\
			20 $(GetDialogWidth));  then
     		eval $COMMAND
			local exitstatus=$?
			if [ $exitstatus = 0 ];  then
				whiptail --title  "ZFS-Bash-GUI" --msgbox "Pool $G_POOL_NAME destroyed successfully!" 10 $(GetDialogWidth)
			else
			    whiptail --title  "ZFS-Bash-GUI" --msgbox "Error while destroying pool $G_POOL_NAME!\n\n$(<zfs-bash-gui.err)" 10 $(GetDialogWidth)
			fi
		fi		
	fi
}

function MainDialogFunc() {
	local -i DIALOG_OPTIONS_COUNT=4
	local -i MENU_HEIGHT=$(( 9 + $DIALOG_OPTIONS_COUNT))

	while :; do
		RESULT=$(whiptail --title "ZFS-Bash-GUI"\
		--menu "Choose an option and press OK\nPress Cancel to Exit" \
		$MENU_HEIGHT $(GetDialogWidth) $DIALOG_OPTIONS_COUNT \
        "1" "Pools status" \
        "2" "Pools list" \
        "3" "Create pool" \
        "4" "Destroy pool" 3>&1 1>&2 2>&3)
 
		local exitstatus=$?
		if [ $exitstatus = 0 ];  then
		     case $RESULT in
		     	1)
					RESULT=""
					#whiptail --title  "ZFS-Bash-GUI" --msgbox --scrolltext "$(zpool status 2>&1)" 10 $(GetDialogWidth)
					clear && zpool status 2>&1 && echo "" && read -n 1 -p "Press any key to continue..."
					;;
				2)
					RESULT=""
					#whiptail --title  "ZFS-Bash-GUI" --msgbox --scrolltext "$(zpool status 2>&1)" 10 $(GetDialogWidth)
					clear && zpool list -o name,size,allocated,free,checkpoint,expandsize,fragmentation,capacity,dedupratio,health,altroot
		 			2>&1 && echo "" && read -n 1 -p "Press any key to continue..."
					;;
			    3)      
		          	RESULT=""
		          	CreatePoolFunc
		          	;;
		    	4)
				  	RESULT=""
		          	DestroyPoolFunc
		          	;;
		     	*)	
				  	whiptail --title  "ZFS-Bash-GUI" --msgbox  "MainDialogFunc Error!" 10 $(GetDialogWidth)
				  	RESULT=""
			esac
		else
		     exit 0
		fi
	done
}

MainDialogFunc