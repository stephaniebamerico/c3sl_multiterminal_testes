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

#### Description: Given a specific display, these functions create and write in a window.
#### There should already be an Xorg/Xephyr running in this display.
#### Written by: Stephanie Briere Americo - sba16@c3sl.inf.ufpr.br on 2017.

## Script/function constants
NEW_WINDOW="seat-parent-window"
WRITE_MESSAGE="write-message"
WAIT_PROCESS="wait_process"

create_window () {
	#### Description: Create a window in a specific display.
	#### PID_WINDOWS, ID_WINDOWS and WINDOW_COUNTER are declared in "multiseat-controller.sh".
	
	## Get screen resolution
	screen_Resolution_X=$(xdpyinfo -display ${DISPLAY_XORGS[$WINDOW_COUNTER]} | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/' | cut -d'x' -f1) #/ $(($WINDOW_COUNTER+1)) ))
	screen_Resolution_Y=x$(xdpyinfo -display ${DISPLAY_XORGS[$WINDOW_COUNTER]} | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/' | cut -d'x' -f2)
	SCREEN_RESOLUTION=$screen_Resolution_X$screen_Resolution_Y

	WINDOW_NAME=w$(($WINDOW_COUNTER+1))

	## Creates a new window and get the pid to destroy the window later
	$NEW_WINDOW $SCREEN_RESOLUTION+0+0 $WINDOW_NAME &
	PID_WINDOWS[$WINDOW_COUNTER]=$!

	$WAIT_PROCESS ${PID_WINDOWS[$WINDOW_COUNTER]}

	## Get the window id
	ID_WINDOWS[$WINDOW_COUNTER]=$(xwininfo -name $WINDOW_NAME | grep "Window id" | cut -d ' ' -f4)

	write_window wait_load $WINDOW_COUNTER

	## Increases the number of windows
	WINDOW_COUNTER=$(($WINDOW_COUNTER+1))
}

write_window() {
	#### Description: Writes in a specific window on a particular display.
	#### Parameters: $1 - message to be written; $2 - display to be used. 
	#### DISPLAY_XORGS and ID_WINDOWS are declared in "multiseat-controller.sh".
	
	export DISPLAY=${DISPLAY_XORGS[$2]}
	case $1 in
		ok) 
			$WRITE_MESSAGE ${ID_WINDOWS[$2]} "Monitor configurado, aguarde o restante ficar pronto" ;;
		wait_load) 
			$WRITE_MESSAGE ${ID_WINDOWS[$2]} "Aguarde" ;;
		press_key) 
			$WRITE_MESSAGE ${ID_WINDOWS[$2]} "Pressione a tecla F$(($2+1))" ;;
		press_mouse) 
			$WRITE_MESSAGE ${ID_WINDOWS[$2]} "Pressione o botão esquerdo do mouse" ;;
    esac
}