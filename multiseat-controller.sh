#!/bin/bash

# Copyright (C) 2017 Centro de Computacao Cientifica e Software Livre
# Departamento de Informatica - Universidade Federal do Parana - C3SL/UFPR
#
# This file is part of le-multiterminal
#
# le-multiterminal is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
# USA.

#### Name: multiseat-controller.sh
#### Description: Prepares the environment and launches the seat configuration scripts.
#### Xorg that communicates with the Thinnetworks card should already be running.
#### Written by: Stephanie Briere Americo - sba16@c3sl.ufpr.br on 2017.

set -x

#TODO: arrumar caminhos

export PATH=$PATH:$(pwd)

## Auxiliary scripts
source find-devices.sh
source window-acess.sh

## Path constants
MC3SL_SCRIPTS=$(pwd) #/usr/sbin/ 
MC3SL_DEVICES=devices #/etc/mc3sl/devices/ 
MC3SL_LOGS=$(pwd) #/etc/mc3sl/logs/ 

## Script/function in other file 
DISCOVER_DEVICES="$MC3SL_SCRIPTS/discover-devices"
FIND_KEYBOARD="$MC3SL_SCRIPTS/find_keyboard" # "find-devices.sh"
CREATE_WINDOW="$MC3SL_SCRIPTS/create_window" # "window-acess.sh"
WRITE_WINDOW="$MC3SL_SCRIPTS/write_window" # "window-acess.sh"

## Macros
FAKE_DISPLAY=:90 # display to access fake-seat (secondary card)
OUTPUTS=("LVDS" "VGA") # output options

## Variables 
WINDOW_COUNTER=0 # how many windows were created
N_SEATS_LISTED=0 # how many seats are there in the system
ONBOARD=0 # if the onboard is connected
declare -a DISPLAY_XORGS # saves the display of the Xorg processes launched
declare -a ID_WINDOWS # save the created window ids (used in window-acess.sh)

configure_devices () {
	# Run configuration script for each seat
	for WINDOW in `seq 0 $(($WINDOW_COUNTER-1))`; do
		$FIND_KEYBOARD $(($WINDOW+1)) $ONBOARD &

		$WRITE_WINDOW press_key $WINDOW
	done
}

kill_processes () {
	# Cleans the system by killing all the processes it has created
	if [[ -n "$(ls | grep lock)" ]]; then
		rm lock*
	fi

	if [[ -n "$(ls $MC3SL_DEVICES)" ]]; then
		rm -f $MC3SL_DEVICES/*
	fi

	pkill -P $$
}

### TODO: Serviços que precisam rodar ANTES desse script 
systemctl stop lightdm
Xorg :90 -seat __fake-seat-1__ -dpms -s 0 -nocursor &
sleep 2
### TO-DO end

############ BEGIN ############

if [ "$(cat "/sys$(udevadm info /sys/class/drm/card0 | grep "P:" | cut -d " " -f2)/card0-VGA-1/status")" == "connected" ]; then
	# If a monitor is connected to the onboard, it runs Xorg and creates the window for it too
	DISPLAY_XORGS[$WINDOW_COUNTER]=:$(($WINDOW_COUNTER+10))
	export DISPLAY=${DISPLAY_XORGS[$WINDOW_COUNTER]}

	Xorg ${DISPLAY_XORGS[$WINDOW_COUNTER]} &
	sleep 1 # TODO

	$CREATE_WINDOW
	
	ONBOARD=1
else
	WINDOW_COUNTER=1
fi

# The fake_seat display needs to be exported to run the Xephyr that communicate with it
export DISPLAY=$FAKE_DISPLAY

for i in `seq 0 1`; do
	# Display for each output
	DISPLAY_XORGS[$WINDOW_COUNTER]=:$((WINDOW_COUNTER+10))

	# Run Xephyr to type in this output
	Xephyr ${DISPLAY_XORGS[$WINDOW_COUNTER]} -output ${OUTPUTS[$WINDOW_COUNTER]} -noxv &
	sleep 2 # TODO

	# Export display and create a window to write on this output
	export DISPLAY=${DISPLAY_XORGS[$WINDOW_COUNTER]}
	$CREATE_WINDOW

	# Again: the fake_seat display needs to be exported
	export DISPLAY=$FAKE_DISPLAY
done

#loginctl seat-status seat-V0 | grep $(echo "/sys/devices/pci0000:00/0000:00:1a.0/usb1/1-1/1-1.2/1-1.2.2/1-1.2.2:1.0/0003:04B3:310C.0008/input/input10" | rev | cut -d "/" -f1 | rev)

configure_devices

# Wait until all seats are configured
N_SEATS_LISTED=$(($(loginctl list-seats | grep -c "seat-")+$ONBOARD))
CONFIGURED_SEATS=0
while [[ $CONFIGURED_SEATS -le $N_SEATS_LISTED ]]; do
    wait -n $PID_FIND_DEVICES
    CONFIGURED_SEATS=$(($CONFIGURED_SEATS+1))
done

kill_processes

#systemctl start lightdm

exit 0
