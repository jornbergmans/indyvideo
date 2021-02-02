#!/usr/bin/env sh

LFTP="$(command -v lftp)"
OUTFOLDER="/Volumes/CONTENTLAB/IFFR2021/STUDIOS/STUDIO_UIT"
DATE="$(date "+%m_%d")"
TIME="$(date "+%H%M")"

get_files() {
  LOGIN="root:root@${IP}"

  echo "Connecting to ${IP}."

  RDIRS="$(/usr/local/bin/lftp -e 'find -d 2; quit;' "${IP}")"

  for RDIR in ${RDIRS}; do
    if [ "${RDIR}" = "./1/" ] || [ "${RDIR}" = "./2/" ]; then
      echo "Sync job for $DATE at $TIME"
      echo "Scanning ${RDIR}."
      MCCTEST="$(/usr/local/bin/lftp -e 'glob echo "*mcc"; quit;' "${LOGIN}"/"${RDIR}")"
      MOVTEST="$(/usr/local/bin/lftp -e 'glob echo "*mov"; quit;' "${LOGIN}"/"${RDIR}")"

#      echo "MCC test == ${MCCTEST}"
#      echo "Mov test == ${MOVTEST}"

      if [ -n "${MCCTEST}" ] && [ -n "${MOVTEST}" ]; then
        echo "Recording still in progress, skipping mov file."
      elif [ -z "${MCCTEST}" ] && [ -n "${MOVTEST}" ]; then
        echo "No MCC file found, checking for mov file."
        echo "Mov file found, syncing directory to ${OUTLOC}."
            mkdir -p "${OUTLOC}"
#        /usr/local/bin/lftp -e "cls -1l; quit;" "${LOGIN}"/"${RDIR}"
        if [ -d "${OUTLOC}" ]; then
          cd "${OUTLOC}" || exit
          /usr/local/bin/lftp -e 'mirror -c -f *.mov ; quit;' "${LOGIN}"/"${RDIR}"
#          /usr/local/bin/lftp -e 'mirror -c -f *.mov --Remove-source-files ; quit;' "${LOGIN}"/"${RDIR}"
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

for STUDIO in 1 2 3 4; do

#  if [ "${STUDIO}" = "1" ]; then
#    STUDIO_NAME="INBEL_1"
#    IPRANGE="121 122 123"
  if [ "${STUDIO}" = "2" ]; then
    STUDIO_NAME="INBEL_2"
    IPRANGE="124 141"
  else
    IPRANGE=""
  fi


  if [ -n "${IPRANGE}" ]; then
    for IPVAR in ${IPRANGE}; do
      OUTLOC="${OUTFOLDER}/${STUDIO_NAME}/${DATE}/SYNC_${TIME}/${IPVAR}"
#      echo "${IPVAR}"
      IP="192.168.110.${IPVAR}"
#      echo "${IP}"
      get_files
    done
  fi

done

