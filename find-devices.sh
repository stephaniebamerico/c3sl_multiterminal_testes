#!/bin/bash

## Script/function constants
READ_DEVICES=read-devices
WRITE_W=write_window
DEVICES=devices
declare -a SEATS_LISTED # save the name of the existing seats


find_keyboard () {
	fKey=$1
	wNum=$(($fKey-1))
	ONBOARD=$2

	## Discovers secondary seats (equivalent to how many monitors are connected)
	#N_SEATS_LISTED=0
	#while read cSeat; do
	#	SEATS_LISTED[$N_SEATS_LISTED]=$cSeat
	#	N_SEATS_LISTED=$(($N_SEATS_LISTED+1))
	#done < <(loginctl list-seats | grep "seat-")
	#SEATS_LISTED[$N_SEATS_LISTED]="seat0"

	#SEAT_NAME=${SEATS_LISTED[$wNum]}

	echo "Starting configuration: F$fKey : $SEAT_NAME"

	CREATED=0
	while (( ! CREATED )); do
		KEYBOARDS=$(discover-devices kevdev | cut -f2)

		for i in `ls $MDM_DEVICES | grep "\<keyboard"`; do
			KEYBOARDS=$(sed "s#$i##g" <<< $KEYBOARDS)
		done

		if [ -z "$KEYBOARDS" ]; then
		    echo "No keyboards connected"
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

		CREATED=1

		ln -sf $PRESSED $DEVICES/keyboard_$SEAT_NAME

		for i in `ls $DEVICES | grep "\<keyboard"`; do
		    if [ "$i" != "keyboard_$SEAT_NAME" ]; then
			AUX=$(stat -c %N $DEVICES/$i | cut -d '>' -f2 | cut -d "'" -f2)
			if [ "$AUX" = "$PRESSED" ]; then
			    # Keyboard link already exists...
			    rm -f $DEVICES/keyboard_$SEAT_NAME
			    CREATED=0
			fi
		    fi
		done
	done

	SYS_DEV=/sys$(udevadm info $PRESSED | grep 'P:' | cut -d ' ' -f2- | sed -r 's/event.*$//g')

	if [ -n "$SYS_DEV" ]; then 
		# Now we know the seat/output
		SEAT_NAME=${SEATS_LISTED[$wNum]}

		echo -ne "\n#Keyboard: $SYS_DEV $SEAT_NAME" >> log_teste

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

	echo "INICIANDO MOUSE"

    while (( ! CREATED && ! TIMEOUT )); do
		MICE=$($DISCOVER_DEVICES mevdev | cut -f2)

		for i in `ls $MDM_DEVICES | grep "\<mouse"`; do
			MICE=$(sed "s#$i##g" <<< $MICE)
		done

		if [ -z "$MICE" ]; then
		    echo "No mice connected"
		    sleep 1
		    continue
		fi

		# Create the lock
		LOCK_EXISTS=1
		$WRITE_W wait_load $wNum
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
		$WRITE_W press_mouse $wNum

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

		CREATED=1

		ln -sf $PRESSED $DEVICES/mouse_$SEAT_NAME

		for i in `ls $DEVICES | grep "\<mouse"`; do
		    if [ "$i" != "mouse_$SEAT_NAME" ]; then
			AUX=$(stat -c %N $DEVICES/$i | cut -d '>' -f2 | cut -d "'" -f2)
			if [ "$AUX" = "$PRESSED" ]; then
			    # Mouse link already exists...
			    rm -f $DEVICES/mouse_$SEAT_NAME
			    CREATED=0
			fi
		    fi
		done

		rm -f ${MC3SL_DEVICES}/lock${fKey}
    done

    SYS_DEV=/sys$(udevadm info $PRESSED | grep 'P:' | cut -d ' ' -f2- | sed -r 's/event.*$//g')

    if [[ "$CREATED" -eq 1 && -n "$SYS_DEV" ]]; then 
		echo -ne "\n#Mouse: $SYS_DEV $SEAT_NAME" >> log_teste

		loginctl attach $SEAT_NAME $SYS_DEV

		$WRITE_W ok $wNum

		exit 1
	else
		$WRITE_W press_key $wNum
		rm -f $DEVICES/keyboard_$SEAT_NAME
		find_keyboard $fKey $SEAT_NAME
	fi
}
