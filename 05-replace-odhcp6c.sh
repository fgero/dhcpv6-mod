#!/bin/bash

file_name="odhcp6c"
file="/usr/sbin/${file_name}"
mod_script="/data/dhcpv6-mod/${file_name}.sh"
mod_bin="/data/local/bin/${file_name}"

${mod_bin} -h 2>&1 | grep -q '\-K ' || { echo "ERROR: Valid modified binary not found in ${mod_bin}"; exit 1; }
echo "Valid modified binary (with -K Cos option) found in ${mod_bin}"

case "$(file -b --mime-type ${file})" in
    "application/x-pie-executable")
        echo "$file: detected as an original Unifi executable"
        mv ${file} ${file}-org
        [[ $? -ne 0 ]] && exit 1 || echo "$file: renamed ${file}-org"
        cp -p ${mod_script} ${file}
        [[ $? -ne 0 ]] && exit 1 || echo "$file: replaced by ${mod_script}"
        killall udhcpc odhcp6c
        ;;
    "text/x-shellscript")
        echo "$file: already a shell script, nothing done"
        diff -q ${file} ${mod_script}
        [[ $? -ne 0 ]] && echo "WARNING: $file may be outdated compared to ${mod_script}"
        exit 0
        ;;
    *)
        echo "ERROR: unable to check file type of ${file}"
        exit 1
        ;;
esac
