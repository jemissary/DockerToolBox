#!/bin/bash

trap '[ "$?" -eq 0 ] || read -p "Looks like something went wrong in step ´$STEP´... Press any key to continue..."' EXIT

# TODO: I'm sure this is not very robust.  But, it is needed for now to ensure
# that binaries provided by Docker Toolbox over-ride binaries provided by
# Docker for Windows when launching using the Quickstart.
export PATH="/d/Repository/Docker:$PATH"
DOCKER_MACHINE=./docker-machine.exe

STEP="Looking for vboxmanage.exe"
if [ ! -z "$VBOX_MSI_INSTALL_PATH" ]; then
  VBOXMANAGE="${VBOX_MSI_INSTALL_PATH}VBoxManage.exe"
else
  VBOXMANAGE="${VBOX_INSTALL_PATH}VBoxManage.exe"
fi

STEP="Choose for exist Docker machine"
VM_COUNT="$(eval VBoxManage list vms | grep -c ".*")"

if [ $VM_COUNT -ge 1 ]; then
  echo "******** Please enter your choise of Docker machine:(1-$[$VM_COUNT+1]) ****"
  echo ""
  "${VBOXMANAGE}" list vms | sed 's/ .*//g' | awk '{printf("%2d %s\n", NR, $0)}'
  echo " $[$VM_COUNT+1] \"Create a new machine\""
  echo ""
  echo "**************************************************************"
  echo ""
  EXIST_VM_ARR=($(vboxmanage list vms | sed 's/ .*//g' | sed 's/"//g'))
  read -p "Select an exist Docker machine:" DOCKER_MACHING_NAME_IDX
  if [ $DOCKER_MACHING_NAME_IDX -eq $[$VM_COUNT+1] ]; then
     read -p "Please input a new Docker machine name:" DOCKER_MACHING_NAME_DEF
     VM=${DOCKER_MACHINE_NAME-$DOCKER_MACHING_NAME_DEF}
  elif [ $DOCKER_MACHING_NAME_IDX -lt 1 -o $DOCKER_MACHING_NAME_IDX -gt $VM_COUNT ]; then
     echo "No selected Docker machine exist"
     exit 1
  else
     VM=${DOCKER_MACHINE_NAME-${EXIST_VM_ARR[$[$DOCKER_MACHING_NAME_IDX - 1]]}}
  fi
else
  read -p "Please input a new Docker machine name:" DOCKER_MACHING_NAME_DEF
  VM=${DOCKER_MACHINE_NAME-$DOCKER_MACHING_NAME_DEF}
fi  

BLUE='\033[1;34m'
GREEN='\033[0;32m'
NC='\033[0m'

#clear all_proxy if not socks address
if  [[ $ALL_PROXY != socks* ]]; then
  unset ALL_PROXY
fi
if  [[ $all_proxy != socks* ]]; then
  unset all_proxy
fi

if [ ! -f "${DOCKER_MACHINE}" ]; then
  echo "Docker Machine is not installed. Please re-run the Toolbox Installer and try again."
  exit 1
fi

if [ ! -f "${VBOXMANAGE}" ]; then
  echo "VirtualBox is not installed. Please re-run the Toolbox Installer and try again."
  exit 1
fi

"${VBOXMANAGE}" list vms | grep \""${VM}"\" &> /dev/null
VM_EXISTS_CODE=$?

set -e

STEP="Checking if machine $VM exists"
if [ $VM_EXISTS_CODE -eq 1 ]; then
  "${DOCKER_MACHINE}" rm -f "${VM}" &> /dev/null || :
  rm -rf /d/Repository/Docker/machines/"${VM}"
  #set proxy variables if they exists
  if [ "${HTTP_PROXY}" ]; then
    PROXY_ENV="$PROXY_ENV --engine-env HTTP_PROXY=$HTTP_PROXY"
  fi
  if [ "${HTTPS_PROXY}" ]; then
    PROXY_ENV="$PROXY_ENV --engine-env HTTPS_PROXY=$HTTPS_PROXY"
  fi
  if [ "${NO_PROXY}" ]; then
    PROXY_ENV="$PROXY_ENV --engine-env NO_PROXY=$NO_PROXY"
  fi
  "${DOCKER_MACHINE}" create -d virtualbox "${VM}"

  echo "${VM} created sucessfully, adjusting memory size on $VM now."
  "${DOCKER_MACHINE}" stop "${VM}"
  read -p "Input memory size (number only) on $VM:" DEF_VM_MEM
  SYS_MEM="$(eval "systeminfo" | grep "Total Physical Memory" | cut -d':' -f 2- | sed 's/ //g' | sed 's/MB//g' | sed 's/,//g')"
  if [ $DEF_VM_MEM -gt $[$SYS_MEM/2] ]; then
    echo "Inputted memory size is too large"
    exit 1
  fi
  VM_MEM="$(eval "VBoxManage.exe showvminfo ${VM}" | grep "Memory size" | cut -d':' -f 2- | sed 's/ //g' | sed 's/MB//g')"
  if [ "$VM_MEM" != "$DEF_VM_MEM" ]; then
    "${VBOXMANAGE}" modifyvm $VM --memory $DEF_VM_MEM
    echo "Memory size:$DEF_VM_MEM"MB" setted successfully on $VM"
  else
    echo "Memory size is OK on $VM"
  fi

  echo "adjusting CPU numbers on $VM now."
  LOGICALPROCESSORS_INDEX="$(eval "wmic cpu" | sed -n '1p' | grep -aob 'NumberOfLogicalProcessors' | grep -oE '^[0-9]+')"
  VALUE_LINE="$(eval "wmic cpu" | sed -n '2p')"
  LOGICALPROCESSORS_NUM=${VALUE_LINE:$LOGICALPROCESSORS_INDEX:2}
  if [ $LOGICALPROCESSORS_NUM -ge 4 ]; then
    "${VBOXMANAGE}" modifyvm $VM --cpus 2
    echo "CPU numbers setted to 2 successfully on $VM"
  else
     echo "Logical processors is too less"
  fi
fi

STEP="Checking status on $VM"
VM_STATUS="$(${DOCKER_MACHINE} status ${VM} 2>&1)"
if [ "${VM_STATUS}" != "Running" ]; then
  "${DOCKER_MACHINE}" start "${VM}"
  yes | "${DOCKER_MACHINE}" regenerate-certs "${VM}"
fi

STEP="Setting env"
eval "$(${DOCKER_MACHINE} env --shell=bash --no-proxy ${VM})"

STEP="Finalize"
clear
cat << EOF


                        ##         .
                  ## ## ##        ==
               ## ## ## ## ##    ===
           /"""""""""""""""""\___/ ===
      ~~~ {~~ ~~~~ ~~~ ~~~~ ~~~ ~ /  ===- ~~~
           \______ o           __/
             \    \         __/
              \____\_______/

EOF
echo -e "${BLUE}docker${NC} is configured to use the ${GREEN}${VM}${NC} machine with IP ${GREEN}$(${DOCKER_MACHINE} ip ${VM})${NC}"
echo "For help getting started, check out the docs at https://docs.docker.com"
echo
cd

docker () {
  MSYS_NO_PATHCONV=1 docker.exe "$@"
}
export -f docker

if [ $# -eq 0 ]; then
  echo "Start interactive shell"
  exec "$BASH" --login -i
else
  echo "Start shell with command"
  exec "$BASH" -c "$*"
fi
