#!/bin/bash

# usb-libvirt-hotplug.sh
DOMAIN="win10"
DIR=/opt/usb-libvirt-hotplug
PARSE_USB=${DIR}/parse_usb.sh
BLACKLIST=${DIR}/usb.blacklist
ALLOWLIST=${DIR}/usb.allowlist
LOCK_FILE=${DIR}/hotplug.lock

PROG="$(basename "$0")"
if [ ! -t 1 ]; then
  # stdout is not a tty. Send all output to syslog.
  coproc logger --tag "${PROG}"
  exec >&${COPROC[1]} 2>&1
fi

(
  flock -x 200

  if ! [[ $(virsh dominfo ${DOMAIN}) == *"running"* ]]; then
  	echo "VM $DOMAIN is not running, do nothing"
  	exit 0
  fi

  while IFS= read -r usb || [[ "$usb" ]]; do
	if ! [[ $usb == "Bus "* ]]; then
		continue
	fi
	echo "usb unplugged: ${usb}"

	VendorID=$(echo $usb | cut -d ' ' -f 6 | cut -d ':' -f 1)
	DeviceID=$(echo $usb | cut -d ' ' -f 6 | cut -d ':' -f 2)
	busnum="$(echo ${usb} | cut -d' ' -f2)"
	devnum="$(echo ${usb} | cut -d' ' -f4 | cut -d':' -f1)"
	busnum=$((10#$busnum))
	devnum=$((10#$devnum))

        /usr/bin/virsh detach-device "${DOMAIN}" /dev/stdin<<END
<hostdev mode='subsystem' type='usb' managed='yes'>
  <source startupPolicy='optional'>
    <vendor id='0x${VendorID}' />
    <product id='0x${DeviceID}' />
    <address bus='${busnum}' device='${devnum}' />
  </source>
</hostdev>
END
  done <<< $($PARSE_USB $DOMAIN | grep -v -f <(lsusb | cut -d " " -f 1-6) | uniq)

  while IFS= read -r usb || [[ "$usb" ]]; do
	if ! [[ $usb == "Bus "* ]]; then
		continue
	fi
	echo "usb plugged: ${usb}"

	VendorID=$(echo $usb | cut -d ' ' -f 6 | cut -d ':' -f 1)
	DeviceID=$(echo $usb | cut -d ' ' -f 6 | cut -d ':' -f 2)
	busnum="$(echo ${usb} | cut -d' ' -f2)"
	devnum="$(echo ${usb} | cut -d' ' -f4 | cut -d':' -f1)"
	busnum=$((10#$busnum))
	devnum=$((10#$devnum))

	/usr/bin/virsh attach-device "${DOMAIN}" /dev/stdin<<END
<hostdev mode='subsystem' type='usb' managed='yes'>
  <source startupPolicy='optional'>
    <vendor id='0x${VendorID}' />
    <product id='0x${DeviceID}' />
    <address bus='${busnum}' device='${devnum}' />
  </source>
</hostdev>
END
  #done <<< $(lsusb | grep -v -f $BLACKLIST | grep -v -f <($PARSE_USB $DOMAIN) | uniq)
  done <<< $(lsusb | grep -f $ALLOWLIST | grep -v -f <($PARSE_USB $DOMAIN) | uniq)

) 200>"$LOCK_FILE"
