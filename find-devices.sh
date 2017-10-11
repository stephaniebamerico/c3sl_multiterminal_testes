#!/bin/bash

## Script/function constants
READ_DEVICES=read-devices

find_keyboard () {
	fKey=$1
	wNum=$(($fKey-1))
	SEAT_NAME=$2

	echo "Starting configuration: F$fKey : $SEAT_NAME"

	CREATED=0
	while (( ! CREATED )); do
		KEYBOARDS=$(discover-devices kevdev | cut -f2)

		if [ -z "$KEYBOARDS" ]; then
		    echo "No keyboards"
		    sleep 1
		    continue
		fi

		# See if someone presses the key:
		PRESSED=$($READ_DEVICES $fKey $KEYBOARDS | grep '^detect' | cut -d'|' -f2)
		echo "PRESSED=$PRESSED"

		if [ -z "$PRESSED" ]; then # if $READ_DEVICES gets killed the script won't do bad stuff
		    continue
		fi

		if [ "$PRESSED" = 'timeout' ]; then
		    continue
		fi

		SYS_DEV=/sys$(udevadm info $PRESSED | grep 'P:' | cut -d ' ' -f2- | sed -r 's/event.*$//g')

		CREATED=1
	done

	if [ -n "$SYS_DEV" ]; then 
		# show the keyboard
		echo -n "Keyboard:" $SYS_DEV

		loginctl attach $SEAT_NAME $SYS_DEV

		find_mouse $fKey $SEAT_NAME
		exit 1
	else
		echo "CAN NOT FIND KEYBOARD"

		exit 0
	fi
}

find_mouse () {
	fKey=$1
	SEAT_NAME=$2

	CREATED=0
	TIMEOUT=0
    while (( ! CREATED && ! TIMEOUT )); do
		MICE=$($DISCOVER_DEVICES mevdev | cut -f2)

		if [ -z "$MICE" ]; then
		    echo "No mice"
		    sleep 1
		    continue
		fi

		# Create the lock
		LOCK_EXISTS=1
		$WRITE_ME wait_load $wNum
		while (( LOCK_EXISTS )); do
		    # creates lock to prevent someone from creating while checking
		    touch ${MC3SL_DEVICES}/lock${fKey}
		    LOCK_EXISTS=0
		    
		    # check if another lock exists
		    for i in `ls $MC3SL_DEVICES | grep "\<lock"`; do
				if [ "$i" != "lock${fKey}" ]; then
			    	LOCK_EXISTS=1
				fi
		    done

		    # if another lock exists, wait until it is not removed
		    if (( LOCK_EXISTS )); then
				rm -f ${MC3SL_DEVICES}/lock${fKey}
				sleep 1;
		    fi
		done

		# Now we have the lock!
		$WRITE_ME press_mouse $wNum

		# See if someone presses the button:
		PRESSED=$($READ_DEVICES 13 $MICE | grep '^detect' | cut -d'|' -f2)

		if [ -z "$PRESSED" ]; then # if $READ_DEVICES gets killed the script won't do bad stuff
		    rm -f ${MC3SL_DEVICES}/lock${fKey}
		    continue
		fi

		if [ "$PRESSED" = 'timeout' ]; then
		    # Give other machines the opportunity to enter the lock
		    rm -f ${MC3SL_DEVICES}/lock${fKey}
		    TIMEOUT=1
		    continue
		fi

		SYS_DEV=/sys$(udevadm info $PRESSED | grep 'P:' | cut -d ' ' -f2- | sed -r 's/event.*$//g')

		CREATED=1

		rm -f ${MC3SL_DEVICES}/lock${fKey}
    done

    if [[ "$CREATED" -eq 1 && -n "$SYS_DEV" ]]; then 
		# show the mouse
		echo -n "Mouse:" $SYS_DEV

		loginctl attach $SEAT_NAME $SYS_DEV

		$WRITE_ME ok $wNum

		exit 1
	else
		$WRITE_ME press_key $wNum
		find_keyboard $fKey $SEAT_NAME
	fi
}
