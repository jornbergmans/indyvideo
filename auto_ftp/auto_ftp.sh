#!/usr/bin/env sh

OUTFOLDER="/Volumes/CONTENTLAB/IFFR2021/STUDIOS/STUDIO_UIT"
DATE="$(date "+%m_%d")"
TIME="$(date "+%H%M")"

check_lftp() {

# We're using an external application 'lftp' to do the actual file transfer.
# This function checks if LFTP is found in $PATH. If it can't be found / executed, the function will download and compile lftp.
# In a future version we would want to install lftp in the container, and exclude it from the script.

LFTP="$(command -v lftp)"

if [ -z "${LFTP}" ]; then
  curl -JL "https://lftp.tech/ftp/lftp-4.9.2.tar.gz" --output "$PWD/lftp-4.9.2.tar.gz"
  tar xf "$PWD/lftp-4.9.2.tar.gz"
  cd "./lftp-4.9.2" || echo "Could not change directory to build lftp." && exit
  ./configure
  make
  make install
  LFTP="$PWD/lftp-4.9.2/lftp"
  cd - || exit
fi

            }


get_files() {

# This function does all the hard work. It logs into the FTP, finds a list of the remote directories (RDIRS),
# then checks those directories for two types of files:
# .mcc files are the Hyperdeck's 'lock file' - created when a Hyperdeck is recording. If an mcc file is found,
# we're considering the mov file incomplete and will not start a copy.
# If no mcc file is found, we scan for a .mov file. If there is no mov file,
# the Hyperdeck wasn't used for recording and we can skip this folder.
# If there is a .mov, and no .mcc, we consider the recording done and the file usable,
# and will start the mirror copy.

  LOGIN="root:root@${IP}"
  echo "Connecting to ${IP}."
  RDIRS="$("${LFTP}" -e 'find -d 2; quit;' "${IP}")"

  for RDIR in ${RDIRS}; do
    if [ "${RDIR}" = "./1/" ] || [ "${RDIR}" = "./2/" ]; then
      echo "Sync job for $DATE at $TIME"
      echo "Scanning ${RDIR}."
      MCCTEST="$("${LFTP}" -e 'glob echo "*mcc"; quit;' "${LOGIN}"/"${RDIR}")"
      MOVTEST="$("${LFTP}" -e 'glob echo "*mov"; quit;' "${LOGIN}"/"${RDIR}")"

      if [ -n "${MCCTEST}" ] && [ -n "${MOVTEST}" ]; then
        echo "Recording still in progress, skipping mov file."
      elif [ -z "${MCCTEST}" ] && [ -n "${MOVTEST}" ]; then
        echo "No MCC file found, checking for mov file."
        echo "Mov file found, syncing directory to ${OUTLOC}."
            mkdir -p "${OUTLOC}"
#        "${LFTP}" -e "cls -1l; quit;" "${LOGIN}"/"${RDIR}"
        if [ -d "${OUTLOC}" ]; then
          cd "${OUTLOC}" || exit
          "${LFTP}" -e 'mirror -c -f *.mov ; quit;' "${LOGIN}"/"${RDIR}"
#          "${LFTP}" -e 'mirror -c -f *.mov --Remove-source-files ; quit;' "${LOGIN}"/"${RDIR}"
          echo "Transfer complete. Sync ok."
          cd - || exit
        elif [ ! -d "${OUTLOC}" ]; then
          echo "${OUTLOC} is not a valid directory path. Exiting."
          exit 1
        fi
      elif [ -z "${MCCTEST}" ] && [ -z "${MOVTEST}" ]; then
        echo "Studio not in use or card empty. Exiting."
      fi
    fi
  done
}


set_studios() {

# We're setting a list of IP addresses to check per studio.
# Requires a sidecar file STUDIOLIST in the same directory as this script which should contain studio names and a list of IP addresses.
# Reads through the sidecar file, and checks each line for a studio name. (by checking if it is _not_ and IP address. 
# When a studio name is found, it is added to a list. Later on, we will loop over this list to copy files per studio.

STUDIOLIST="$(dirname "$0")/STUDIOLIST.txt"

  while read -r line; do
#    if [ -n "$line" ] && [ "$line" =~ ^([0-9]{3}\.){3}[0-9]{3}& ] ; # NOT POSIX COMPLIANT BUT PRETTIER IN BASH
    if [ -n "${line}" ] && ! grep -Eq "^([0-9]{3}\.){3}[0-9]{3}&" < "${line}" ; then
      STUDIOS="$STUDIOS $line"
    fi
  done < "${STUDIOLIST}"
}

set_ip() {

# Checks each line of the sidecar file for a generic IP(v4) address markup, namely 4 x 3 numbers separated by a dot (.)
# If an IP address is found, it is added to the list of addresses for the current studio.
# We will loop over all of the IPs found to get_files() per studio.

  while read -r line; do
    if [ "$STUDIO" = "$line" ]; then
      while read -r line; do
        if [ -n "${line}" ] && [ "${line}" = "$(echo "$line" | grep -Eq "^([0-9]{3}\.){3}[0-9]{3}&")" ]; then
          IPRANGE="$IPRANGE $line"
        fi
      done
    fi
  done < "$(dirname "$0")/STUDIOLIST.txt"

}


### IF NAME IS MAIN

main() {

# Main function is always the executive order for the functions defined earlier on in the script. 
# While those all do their specific task, this function executes them in order.

check_lftp

set_studios

for STUDIO in $STUDIOS; do
  set_ip
  if [ -n "${IPRANGE}" ]; then
    for IP in ${IPRANGE}; do
      IPSTUB="${IP:-3}"
      OUTLOC="${OUTFOLDER}/${STUDIO}/${DATE}/SYNC_${TIME}/${IPSTUB}"
      get_files
    done
  fi
done

}

main
