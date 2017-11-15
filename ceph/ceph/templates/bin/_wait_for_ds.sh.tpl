#!/bin/bash
set -ex
export LC_ALL=C

if [[ -z "${WAIT_FOR_DS}" ]]; then
    exit 
fi

while [ true ]
  do
    diff=$(kubectl get ds "${WAIT_FOR_DS}" --namespace=${NAMESPACE} -o template --template="{{`{{.status.updatedNumberScheduled}}`}} -eq {{`{{.status.currentNumberScheduled}}`}}" || true)
    if [ $"${diff}" ]; then
        exit
    fi
    sleep 5
done
