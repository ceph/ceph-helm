#!/bin/bash
set -ex
export LC_ALL=C

source variables_entrypoint.sh
source common_functions.sh

if [[ -z "$CEPH_PUBLIC_NETWORK" ]]; then
  log "ERROR- CEPH_PUBLIC_NETWORK must be defined as the name of the network for the OSDs"
  exit 1
fi

if [[ -z "$MON_IP" ]]; then
  log "ERROR- MON_IP must be defined as the IP address of the monitor"
  exit 1
fi

if [[ -z "$MON_IP" || -z "$CEPH_PUBLIC_NETWORK" ]]; then
  log "ERROR- it looks like we have not been able to discover the network settings"
  exit 1
fi

function get_mon_config {
  # Get fsid from ceph.conf
  local fsid=$(ceph-conf --lookup fsid -c /etc/ceph/${CLUSTER}.conf)

  timeout=10
  MONMAP_ADD=""

  while [[ -z "${MONMAP_ADD// }" && "${timeout}" -gt 0 ]]; do
    # Get the ceph mon pods (name and IP) from the Kubernetes API. Formatted as a set of monmap params
    if [[ ${K8S_HOST_NETWORK} -eq 0 ]]; then
        MONMAP_ADD=$(kubectl get pods --namespace=${NAMESPACE} -l application=ceph -l component=mon -o template --template="{{`{{range .items}}`}}{{`{{if .status.podIP}}`}}--add {{`{{.metadata.name}}`}} {{`{{.status.podIP}}`}} {{`{{end}}`}} {{`{{end}}`}}")
    else
        MONMAP_ADD=$(kubectl get pods --namespace=${NAMESPACE} -l application=ceph -l component=mon -o template --template="{{`{{range .items}}`}}{{`{{if .status.podIP}}`}}--add {{`{{.spec.nodeName}}`}} {{`{{.status.podIP}}`}} {{`{{end}}`}} {{`{{end}}`}}")
    fi
    (( timeout-- ))
    sleep 1
  done

  if [[ -z "${MONMAP_ADD// }" ]]; then
      exit 1
  fi

  # Create a monmap with the Pod Names and IP
  monmaptool --create ${MONMAP_ADD} --fsid ${fsid} $MONMAP --clobber
}

get_mon_config $IP_VERSION

chown ceph. /var/log/ceph

# If we don't have mon data locally
if [ ! -e "$MON_DATA_DIR/keyring" ]; then
  if [ ! -e $MON_KEYRING ]; then
    log "ERROR- $MON_KEYRING must exist.  You can extract it from your current monitor by running 'ceph auth get mon. -o $MON_KEYRING' or use a KV Store"
    exit 1
  fi

  if [ ! -e $MONMAP ]; then
    log "ERROR- $MONMAP must exist.  You can extract it from your current monitor by running 'ceph mon getmap -o $MONMAP' or use a KV Store"
    exit 1
  fi

  # Testing if it's not the first monitor, if one key doesn't exist we assume none of them exist
  for keyring in $OSD_BOOTSTRAP_KEYRING $MDS_BOOTSTRAP_KEYRING $RGW_BOOTSTRAP_KEYRING $ADMIN_KEYRING; do
    ceph-authtool $MON_KEYRING --import-keyring $keyring
  done

  # Prepare the monitor store
  ceph-mon --setuser ceph --setgroup ceph --cluster ${CLUSTER} --mkfs -i ${MON_NAME} --inject-monmap $MONMAP --keyring $MON_KEYRING --mon-data "$MON_DATA_DIR"
fi

log "Trying to get the most recent monmap..."
MON_IP_LIST=$(kubectl get pods --namespace=${NAMESPACE} ${KUBECTL_PARAM} -o template --template="{{`{{range .items}}`}}{{`{{if .status.podIP}}`}} {{`{{.status.podIP}}`}} {{`{{end}}`}} {{`{{end}}`}}")

#If there's a quorum, we get the latest monmap
# from one the existing Ceph monitors and
# add ourselves to the cluster
for mon in $MON_IP_LIST; do
  ceph -m $mon --connect-timeout 10 ${CLI_OPTS} mon getmap -o $MONMAP || continue
  ceph-mon --setuser ceph --setgroup ceph --cluster ${CLUSTER} -i ${MON_NAME} --inject-monmap $MONMAP --keyring $MON_KEYRING --mon-data "$MON_DATA_DIR"
  ceph --connect-timeout 10 -m $mon ${CLI_OPTS} mon add "${MON_NAME}" "${MON_IP}:6789"
  break
done
log "SUCCESS"

# start MON
exec /usr/bin/ceph-mon $DAEMON_OPTS -i ${MON_NAME} --mon-data "$MON_DATA_DIR" --public-addr "${MON_IP}:6789"
