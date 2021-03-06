#!/bin/bash

trap '[ "$?" -eq 0 ] || read -p "Looks like something went wrong in step ´$STEP´... Press any key to continue..."' EXIT

echo "clean docker machine on local repository"
read -p "Please input docker machine name:" DOCKER_MACHING_NAME_DEF

DOCKER_MACHINE=./docker-machine.exe

set -e

STEP="Looking for vboxmanage.exe"
if [ ! -z "$VBOX_MSI_INSTALL_PATH" ]; then
  VBOXMANAGE="${VBOX_MSI_INSTALL_PATH}VBoxManage.exe"
else
  VBOXMANAGE="${VBOX_INSTALL_PATH}VBoxManage.exe"
fi

"${VBOXMANAGE}" list vms | grep \""${DOCKER_MACHING_NAME_DEF}"\" &> /dev/null
VM_EXISTS_CODE=$?

STEP="Cleaning for docker machine"
if [ $VM_EXISTS_CODE -eq 1 ]; then
  VM_STATUS="$(${DOCKER_MACHINE} status ${DOCKER_MACHING_NAME_DEF} 2>&1)"
  if [ "${VM_STATUS}" = "Running" ]; then
    "${DOCKER_MACHINE}" stop "${DOCKER_MACHING_NAME_DEF}"
  fi
  "${DOCKER_MACHINE}" rm -f "${DOCKER_MACHING_NAME_DEF}" &> /dev/null
  rm -rf /d/Repository/Docker/machines/"${DOCKER_MACHING_NAME_DEF}"
fi

STEP="Finalize"
clear