#!/bin/bash

xml_data="$(virsh dumpxml $1)"
buss=($(echo "$xml_data" | xmllint --xpath "//hostdev[@type='usb']/source/address/@bus" -))
devs=($(echo "$xml_data" | xmllint --xpath "//hostdev[@type='usb']/source/address/@device" -))
vendor_ids=($(echo "$xml_data" | xmllint --xpath "//hostdev[@type='usb']/source/vendor/@id" -))
product_ids=($(echo "$xml_data" | xmllint --xpath "//hostdev[@type='usb']/source/product/@id" -))

for (( i=0; i<${#buss[@]}; i++ )); do
  bus="${buss[$i]//[!0-9]/}"
  device="${devs[$i]//[!0-9]/}"
  vendor=$(echo ${vendor_ids[$i]} | sed 's/^id="//;s/"$//')
  product=$(echo ${product_ids[$i]} | sed 's/^id="//;s/"$//')
  #echo "Bus $bus Device $device: ID ${vendor}:${product}"
  printf "Bus %03d Device %03d: ID %04x:%04x\n" "$bus" "$device" "$vendor" "$product"
done
