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
#### Written by: Stephanie Briere Americo - sba16@c3sl.inf.ufpr.br on 2017.

####################################################################
#                                                                  #
# ** IMPORTANT **                                                  #
#                                                                  #
# discover-devices uses the "hal" tools to detect input devices.   #
#                                                                  #
# These tools are obsolete, udev is the first alternative indicated#
#    by community.                                                 #
#                                                                  #
# Hal was installed using                                          #
#  add-apt-repository ppa:mjblenner/ppa-hal                        #
#  apt-get update && apt-get install hal                           #
#                                                                  #
####################################################################

set -x

echo "Starting Multiseat C3SL" &>> log_multiterminal

export PATH=$PATH:$(pwd) #TODO

## Auxiliary scripts
source find-devices.sh
source window-acess.sh

## Path constants
MC3SL_SCRIPTS=$(pwd) #/usr/sbin/ #TODO: arrumar caminho
MC3SL_DEVICES=$(pwd) #/etc/mc3sl/devices/ #TODO: arrumar caminho
MC3SL_LOGS=$(pwd) #/etc/mc3sl/logs/ #TODO: arrumar caminho

## Script/function in other file 
DISCOVER_DEVICES="$MC3SL_SCRIPTS/discover-devices"
FIND_KEYBOARD="find_keyboard" # "find-devices.sh"
CREATE_WINDOW="create_window" # "window-acess.sh"
WRITE_WINDOW="write_window" # "window-acess.sh"

## Variables
WINDOW_COUNTER=0
declare -a DISPLAY_XORGS # saves the display of the Xorg processes launched
declare -a ID_WINDOWS # save the created window ids
declare -a SEAT_NAMES # save the name of the seat of each window
declare -a PID_FIND_DEVICES # saves the pid of the "find_devices.sh" processes launched

execute_Xorg () {
	#### Description: Runs Xorg in a specific display.
	#### Parameters: $1 - display to be used.
	
	## Runs Xorg on a specific display and get pid to destroy the process later
	DISPLAY_XORGS[$WINDOW_COUNTER]=$1

	export DISPLAY=${DISPLAY_XORGS[$WINDOW_COUNTER]}

	Xorg ${DISPLAY_XORGS[$WINDOW_COUNTER]} &>> log_Xorg &
	PID_XORGS[$WINDOW_COUNTER]=$!
	# TODO: verificar se Xorg está rodando

	echo "Xorg $DISPLAY is running" &>> log_multiterminal
}

configure_devices () {
	for WINDOW in `seq 0 $(($WINDOW_COUNTER-1))`; do
		$FIND_KEYBOARD $(($WINDOW+1)) ${SEAT_NAMES[$WINDOW]} &>> log_multiterminal &
		PID_FIND_DEVICES[$WINDOW]=$!

		$WRITE_WINDOW press_key $WINDOW
	done
}

wait_process () {
	PID_PROCESS=$1
	TIMEOUT=6
	while [[ $(ps aux | grep $PID_PROCESS -c) -le 1 && $TIMEOUT -gt 1 ]]; do
		echo $PID_PROCESS >> log_temp
		ps aux | grep $PID_PROCESS >> log_temp
		sleep 0.5
		TIMEOUT=$(($TIMEOUT-1))
	done
}

kill_processes () {
	#if [[ -n "$(ls | grep log)" ]]; then
	#	rm log*
	#fi

	if [[ -n "$(ls | grep lock)" ]]; then
		rm lock*
	fi

	pkill -P $$
}

## Stops services that should not be running 
systemctl stop lightdm
## Removes all device assignments previously created with attach 
loginctl flush-devices

### TO-DO: o melhor jeito é garantir que o xorg-daemon.service rode antes
Xorg :90 -seat __fake-seat-1__ -dpms -s 0 -nocursor &>> log_Xorg &
### TO-DO end

## Find the display on which Xorg is running with "__fake-seat__"
FAKE_DISPLAY=:$(ps aux | grep Xorg | cut -d ":" -f4 | cut -d " " -f1)
export DISPLAY=$FAKE_DISPLAY
echo "FAKE_DISPLAY=$FAKE_DISPLAY" &>> log_multiterminal

while read -r outputD ; do
	DISPLAY_XORGS[$WINDOW_COUNTER]=:$WINDOW_COUNTER

	Xephyr ${DISPLAY_XORGS[$WINDOW_COUNTER]} -output $outputD &
	wait_process $!
	sleep 2
	
	export DISPLAY=${DISPLAY_XORGS[$WINDOW_COUNTER]}
	$CREATE_WINDOW

	export DISPLAY=$FAKE_DISPLAY
	
	echo "$outputD: Xephyr is up" &>> log_multiterminal
done < <(xrandr | grep " connected " | cut -d " " -f1)

execute_Xorg :$(($WINDOW_COUNTER+10))
SEAT_NAMES[$WINDOW_COUNTER]=seat0
echo "Onboard monitor: Xorg is up" &>> log_multiterminal

sleep 1

$CREATE_WINDOW

echo "FINALIZANDO..."

read a

kill_processes

exit 0

configure_devices

for device in `seq 0 $(($WINDOW_COUNTER-1))`; do
    wait ${PID_FIND_DEVICES[$device]}
done

kill_processes

#systemctl start lightdm

exit 0
