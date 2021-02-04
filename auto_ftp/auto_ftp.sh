#!/usr/bin/env sh

LFTP="$(command -v lftp)"
OUTFOLDER="/Volumes/CONTENTLAB/IFFR2021/STUDIOS/STUDIO_UIT"
DATE="$(date "+%m_%d")"
TIME="$(date "+%H%M")"

check_lftp() {

if [ -z "${LFTP}" ]; then
  curl -JL "https://lftp.tech/ftp/lftp-4.9.2.tar.gz" --output "$PWD/lftp-4.9.2.tar.gz"
  tar xf "$PWD/lftp-4.9.2.tar.gz"
  cd "./lftp-4.9.2" || echo "Could not change directory to build lftp." && exit
  ./configure
  make
  make install
  LFTP="$PWD/lftp-4.9.2/lftp"
  cd - || exit
#  cd "$(dirname "${0}")" || exit
fi

            }


get_files() {

  LOGIN="root:root@${IP}"
  echo "Connecting to ${IP}."
  RDIRS="$("${LFTP}" -e 'find -d 2; quit;' "${IP}")"

  for RDIR in ${RDIRS}; do
    if [ "${RDIR}" = "./1/" ] || [ "${RDIR}" = "./2/" ]; then
      echo "Sync job for $DATE at $TIME"
      echo "Scanning ${RDIR}."
      MCCTEST="$("${LFTP}" -e 'glob echo "*mcc"; quit;' "${LOGIN}"/"${RDIR}")"
      MOVTEST="$("${LFTP}" -e 'glob echo "*mov"; quit;' "${LOGIN}"/"${RDIR}")"

#      echo "MCC test == ${MCCTEST}"
#      echo "Mov test == ${MOVTEST}"

      if [ -n "${MCCTEST}" ] && [ -n "${MOVTEST}" ]; then
        echo "Recording still in progress, skipping mov file."
      elif [ -z "${MCCTEST}" ] && [ -n "${MOVTEST}" ]; then
        echo "No MCC file found, checking for mov file."
        echo "Mov file found, syncing directory to ${OUTLOC}."
            mkdir -p "${OUTLOC}"
#        "${LFTP}" -e "cls -1l; quit;" "${LOGIN}"/"${RDIR}"
        if [ -d "${OUTLOC}" ]; then
          cd "${OUTLOC}" || exit
#          "${LFTP}" -e 'mirror -c -f *.mov ; quit;' "${LOGIN}"/"${RDIR}"
          "${LFTP}" -e 'mirror -c -f *.mov --Remove-source-files ; quit;' "${LOGIN}"/"${RDIR}"
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

STUDIOLIST="$(dirname "$0")/STUDIOLIST.txt"


  if ! -f 

  while read -r line; do
#    if [ -n "$line" ] && [ "$line" =~ ^([0-9]{3}\.){3}[0-9]{3}& ] ; # NOT POSIX COMPLIANT BUT PRETTIER IN BASH
    if [ -n "${line}" ] && ! grep -Eq "^([0-9]{3}\.){3}[0-9]{3}&" < "${line}" ; then
      STUDIOS="$STUDIOS $line"
    fi
  done < "${STUDIOLIST}"
}

set_ip() {

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
