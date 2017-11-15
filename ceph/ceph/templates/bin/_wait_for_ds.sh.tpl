#!/bin/bash
set -ex
export LC_ALL=C

if [[ -z "${WAIT_FOR_DS}" ]]; then
    exit 
fi

while [ true ]
  do
    ready=1
    IFS=',' read -ra DS <<< "${WAIT_FOR_DS}"
    for ds in "${DS[@]}"; do
      diff=$(kubectl get ds "${ds}" --namespace=${NAMESPACE} -o template --template="{{`{{ eq .status.updatedNumberScheduled .status.currentNumberScheduled }}`}}" || true)
      if [ $"${diff}" == "false"]; then
        ready=0  
      fi
    done
    if [  "${ready}" -eq 0 ]; then
      sleep 5
    fi
done
