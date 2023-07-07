#!/bin/bash

# Overwrite existing script in /sbin/odhcp6c only if --update
[ "$1" = "--update" ] && update='YES' || update='NO'

file_name="odhcp6c"
file="/usr/sbin/${file_name}"
mod_script="/data/dhcpv6-mod/${file_name}.sh"
mod_bin="/data/local/bin/${file_name}"

${mod_bin} -h 2>&1 | grep -q '\-K ' || { echo "Valid modified binary not found in ${mod_bin}"; exit 1; }
echo "Valid modified binary (with -K Cos option) found in ${mod_bin}"

# Avoids wget fw-download.ubnt.com IPv6 endpoints unreachable
grep -sq '^prefer-family' /root/.wgetrc || echo 'prefer-family = IPv4' >> /root/.wgetrc

case "$(file -b --mime-type ${file})" in
    "application/x-pie-executable")
        echo "$file: detected as an original Unifi executable, not our shell script"
        mv ${file} ${file}-org
        [[ $? -ne 0 ]] && exit 1 || echo "$file: renamed ${file}-org"
        cp -p ${mod_script} ${file}
        [[ $? -ne 0 ]] && exit 1 || echo "$file: replaced by ${mod_script}"
        ps -o cmd= -C odhcp6c >/dev/null && killall udhcpc odhcp6c || echo "Note: odhcp6c process not found"
        exit 0
        ;;
    "text/x-shellscript")
        diff -q ${file} ${mod_script}
        if [[ $? -ne 0 ]]; then
            if [[ "$update" = "YES" ]]; then
                cp -p ${mod_script} ${file}
                ps -o cmd= -C odhcp6c >/dev/null && killall udhcpc odhcp6c || echo "Note: odhcp6c process not found"
                echo "NOTE: existing $file shell script has been replaced by ${mod_script}, as --update was specified..."
            else
                echo "WARNING: $file is already a shell script and it is different from ${mod_script}..."
                echo "...but it hasn't been overwriten : to do that you need to use --update argument"
            fi
        else
            echo "$file is already a shell script and is the same as ${mod_script}, nothing done"
        fi
        exit 0
        ;;
    *)
        echo "ERROR: unable to check file type of ${file}"
        exit 1
        ;;
esac