#!/usr/bin/env bash


#################################################################################
# The MIT License (MIT)                                                         #
#                                                                               #
# Copyright (c) 2014, Aaron Herting "qwertos" <aaron@herting.cc>                #
#                                                                               #
# Permission is hereby granted, free of charge, to any person obtaining a copy  #
# of this software and associated documentation files (the "Software"), to deal #
# in the Software without restriction, including without limitation the rights  #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     #
# copies of the Software, and to permit persons to whom the Software is         #
# furnished to do so, subject to the following conditions:                      #
#                                                                               #
# The above copyright notice and this permission notice shall be included in    #
# all copies or substantial portions of the Software.                           #
#                                                                               #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     #
# THE SOFTWARE.                                                                 #
#################################################################################



# Define some color escape codes used later on
GREEN='\e[1;32m'
RED='\e[0;31m'
CYAN='\e[0;36m'
NC='\e[0m'
YELLOW='\e[1;33m'


DEPENDENCIES='cat sed grep ctorrent mktorrent mount df sudo umount read'

workspace=""
drive='/dev/null'
part_aware=""
SECTOR_SIZE="512"

if [[ $1 == "-c" ]] ; then
	if [[ -f $2 ]] ; then
		source $2
	else
		echo "usage $0 [-c <config file>]"
		exit 1
	fi
fi


choose_drive_to_capture () {
	read -p "Please specify a drive to capture: [/dev/sd?|mount|df|dmesg|ls /dev]" option

	if [[ $option == "mount" ]] ; then
		mount
		return
	elif [[ $option == "df" ]] ; then
		df
		return
	elif [[ $option == "dmesg" ]] ; then
		dmesg | less
		return
	elif [[ $option == "ls /dev" ]] ; then
		ls --color /dev
		return
	else
		drive=$option
	fi
}





# Dependancy checking.

dep_check_single () {
  BIN=$1
  
  echo -n "Checking for $BIN ... "
  if which $BIN > /dev/null 2> /dev/null ; then
    echo -e "[ ${GREEN}OK${NC} ]"
  else
    echo -e "[${RED}FAIL${NC}]"
    exit 2
  fi  
}


dep_check () {
  for dep in $DEPENDENCIES ; do
    dep_check_single $dep
  done
}



disk_choose () {
	while [[ $drive == '/dev/null' ]] ; do
		choose_drive_to_capture
		if [[ ! -b $drive && $drive != '/dev/null' ]] ; then
			if [[ -f $drive ]] ; then
				echo -e "${RED}File $drive is not a block special device."
				echo -e "This might have unintended effects.${NC}"
				read -p "Do you wish to continue? [y|N] " option
				if [[ ! ( $option == "y" ||
				          $option == "Y" ||
				          $option == "yes" ) ]] ; then
					drive='/dev/null'
				fi
			else
				echo -e "${RED}File $drive does not exist.${NC}"
				drive='/dev/null'
			fi
		fi
	done


	if mount | grep $drive &> /dev/null ; then
		echo -e "${RED}$drive is currently mounted."
		echo -e "This might have uninteneded effects.${NC}"
		read -p "Would you like to unmount the drive? [Y|n] " option
		if [[ ! ( $option == "n" ||
		          $option == "N" ||
		          $option == "no" ) ]] ; then
	
			sudo umount $drive
	
			if mount | grep $drive &> /dev/null ; then
				echo -e "${RED}$drive is still mounted. Unmount attempt failed."
				echo -e "Exiting...${NC}"
				exit 1
			else
				echo -e "${GREEN}$drive was unmounted${NC}"
			fi
		fi
	else
		echo -e "${GREEN}$drive is not mounted ${NC}"
	fi
}


ws_choose () {
	while [[ $workspace == "" ]] ; do
		read -p "Enter a directory to act as a workspace: (default- pwd) " option
	
		if [[ $option == "" ]] ; then
			option=`pwd`
		fi
			
	
		if [[ -d $option ]] ; then
			if [[ ! ( -x $option &&
			          -w $option &&
			          -r $option ) ]] ; then
				echo -e "${RED}You do not have full permissions in the directory"
				echo -e "$option. Please choose a directory where you have"
				echo -e "full permissions.${NC}"
	
				workspace=""
			else
				workspace=$option
			fi
		else
			echo -e "${RED}Directory ${option} does not exist.${NC}"
		fi
	done
}

choose_part_aware () {
	while [[ $part_aware == "" ]] ; do
		echo -e "${CYAN}BitHash can be partition aware, meaning that it can"
		echo -e "split up the drive based on partition bounderys and each"
		echo -e "will be put in a seperate dd based image file."
		echo -e "Each section of unallocated space will be considered"
	 	echo -e "another partition.${NC}"
		read -p "Would you like BitHash to be partition aware? [y|N] " option

		if [[ ( $option == "y" ||
		        $option == "Y" ||
		        $option == "yes" ) ]] ; then
			part_aware="Yes"
		else
			part_aware="No"
		fi
	done
}

choose_sector_size () {
	while [[ $SECTOR_SIZE == "" ]] ; do
		read -p "Enter a sector size: (Default: 512) " option

		if [[ $option == "" ]] ; then
			option='512'
		fi

		SECTOR_SIZE=$option
	done
}



output_options () {
	echo
	echo -e "Current options are:"
	echo -e "\t1. Drive\t${CYAN}${drive}${NC}"
	echo -e "\t2. Workspace\t${CYAN}${workspace}${NC}"
	echo -e "\t3. Part Aware\t${CYAN}${part_aware}${NC}"
	echo -e "\t4. Sector Size\t${CYAN}${SECTOR_SIZE}${NC}"
	echo
	read -p "Would you like to edit to edit any of the above? [1-4|N] " option

	if [[ $option	== '1' ]] ; then
		drive='/dev/null'
		return 1
	elif [[ $option == '2' ]] ; then
		workspace=''
		return 1
	elif [[ $option == '3' ]] ; then
		part_aware=''
		return 1
	elif [[ $option == '4' ]] ; then
		SECTOR_SIZE=""
		return 1
	else
		return
	fi
}


check_valid () {
	if [[ ( $workspace == '' ||
	        $drive == '/dev/null' ||
	        $part_aware == '' ||
	        $SECTOR_SIZE == '' ) ]] ; then
		return 1
	else
		return 0
	fi
}



make_selections () {
	while ! check_valid ; do 
		disk_choose
		ws_choose
		choose_part_aware
		choose_sector_size

		output_options
	done
}


generate_ws_structure () {
	mkdir -p "$workspace/images"
	mkdir -p "$workspace/torrent"
	echo -n > "$workspace/part_table.col"
	echo -n > "$workspace/capture.info"
	echo -n > "$workspace/fdisk.out"
	echo -n > "$workspace/image_table.col"
}


capture_no_aware () {
	out_image="$workspace/images/disk.dd"
	sudo dd if="$drive" of="$out_image"
}

generate_part_table () {
	fdisk_file="$workspace/fdisk.out"
	part_table="$workspace/part_table.col"

	cat $fdisk_file | sed -n 's|^\(/[a-zA-Z0-9_-/]\+\)\s\+\(\*\?\)\s\+\([0-9+]\+\)\s\+\([0-9+]\+\)\s\+\([0-9+]\+\).*$|\1:\2:\3:\4:\5|gp' > $part_table
}

generate_capture_info () {
	fdisk_file="$workspace/fdisk.out"
	info_file="$workspace/capture.info"
	
	sudo fdisk -l "$drive" > $fdisk_file

	disk=`cat "$fdisk_file" | sed -n 's/^Disk \(.\+\?\):\s\+\([0-9]\+\)\s\+\([A-Z]B\),\s\+\([0-9]\+\)\s\+bytes,\s\+\([0-9]\+\)\s\+sectors.*$/\1/gp'`
	hr_size=`cat "$fdisk_file" | sed -n 's/^Disk \(.\+\?\):\s\+\([0-9]\+\)\s\+\([A-Z]B\),\s\+\([0-9]\+\)\s\+bytes,\s\+\([0-9]\+\)\s\+sectors.*$/\2/gp'`
	hr_unit=`cat "$fdisk_file" | sed -n 's/^Disk \(.\+\?\):\s\+\([0-9]\+\)\s\+\([A-Z]B\),\s\+\([0-9]\+\)\s\+bytes,\s\+\([0-9]\+\)\s\+sectors.*$/\3/gp'`
	full_bytes=`cat "$fdisk_file" | sed -n 's/^Disk \(.\+\?\):\s\+\([0-9]\+\)\s\+\([A-Z]B\),\s\+\([0-9]\+\)\s\+bytes,\s\+\([0-9]\+\)\s\+sectors.*$/\4/gp'`
	full_sectors=`cat "$fdisk_file" | sed -n 's/^Disk \(.\+\?\):\s\+\([0-9]\+\)\s\+\([A-Z]B\),\s\+\([0-9]\+\)\s\+bytes,\s\+\([0-9]\+\)\s\+sectors.*$/\5/gp'`

	unit_size=`cat "$fdisk_file" | sed -n 's/^Units\s\+=.\+\?=\s\+\([0-9]\+\)\s\+bytes.*$/\1/gp'`

	hr_time=`date`
	unix_time=`date +%s`

	echo "Start_Time:$unix_time" >> $info_file
	echo "Start_HR_Time:$hr_time" >> $info_file
	echo "User_Drive:$drive" >> $info_file
	echo "User_Workspace:$workspace" >> $info_file
	echo "User_Part_Aware:$part_aware" >> $info_file
	echo "Fdisk_Disk:$disk" >> $info_file
	echo "Fdisk_HR_Size:$hr_size" >> $info_file
	echo "Fdisk_HR_Unit:$hr_unit" >> $info_file
	echo "Fdisk_Full_Bytes:$full_bytes" >> $info_file
	echo "Fdisk_Full_Sectors:$full_sectors" >> $info_file
	echo "Fdisk_Unit_Size:$unit_size" >> $info_file
}
	
	
capture_parts () {
	part_table="$workspace/part_table.col"
	info_file="$workspace/capture.info"
	image_table="$workspace/image_table.col"
	
	unit_size=`cat $info_file | sed -n 's|^Fdisk_Unit_Size:\([0-9]\+\)\+$|\1|p'`
	max_sectors=`cat $info_file | sed -n 's|^Fdisk_Full_Sectors:\([0-9]\+\)\+$|\1|p'`

	current_skip='0'
	index=`printf "%04d" '0'`

	for line in `cat $part_table` ; do 
		line_start=`echo $line | cut -d: -f3`
		line_end=`echo $line | cut -d: -f4`

		if [[ $current_skip -lt $line_start ]]; then
			dd_count=$(( $line_start - $current_skip ))
			sudo dd if="$disk" \
			   of="${workspace}/images/${index}.dd" \
			   bs="${unit_size}" \
			   count="${dd_count}" \
			   skip="${current_skip}"

			echo "${disk}:${index}:${unit_size}:${dd_count}:${current_skip}" | tee -a $image_table
			current_skip=$line_start
			index=`printf "%04d" $(( $index + 1 ))`
		fi

		dd_count=$(( $line_end - $current_skip ))
		sudo dd if="$disk" \
		   of="${workspace}/images/${index}.dd" \
		   bs="${unit_size}" \
		   count="${dd_count}" \
		   skip="${current_skip}"

		echo "${disk}:${index}:${unit_size}:${dd_count}:${current_skip}" | tee -a $image_table
		current_skip=$line_end
			index=`printf "%04d" $(( $index + 1 ))`
	done

	if [[ $current_skip -lt $max_sectors ]] ; then
		dd_count=$(( $max_sectors - $current_skip ))
		sudo dd if="$disk" \
		   of="${workspace}/images/${index}.dd" \
		   bs="${unit_size}" \
		   count="${dd_count}" \
		   skip="${current_skip}"

		echo "${disk}:${index}:${unit_size}:${dd_count}:${current_skip}" | tee -a $image_table
		current_skip=$line_start
			index=`printf "%04d" $(( $index + 1 ))`
	fi

	full_hash=`cat "${workspace}/images/*.dd" | sha256sum`
}


capture_full () {
	part_table="$workspace/part_table.col"
	info_file="$workspace/capture.info"
	image_table="$workspace/image_table.col"
	
	unit_size=`cat $info_file | sed -n 's|^Fdisk_Unit_Size:\([0-9]\+\)\+$|\1|p'`
	max_sectors=`cat $info_file | sed -n 's|^Fdisk_Full_Sectors:\([0-9]\+\)\+$|\1|p'`

	sudo dd if="${disk}" of="${workspace}/images/full.dd"
}

		



main () {
	dep_check
	make_selections
	generate_ws_structure
	generate_capture_info
	generate_part_table
	if [[ $part_aware == "Yes" ]] ; then
		capture_parts
	else
		capture_full
	fi
}


main



