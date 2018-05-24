#!/bin/bash
set -ex

function osd_disk_prepare {
  if [[ -z "${OSD_DEVICE}" ]];then
    log "ERROR- You must provide a device to build your OSD ie: /dev/sdb"
    exit 1
  fi

  if [[ ! -e "${OSD_DEVICE}" ]]; then
    log "ERROR- The device pointed by OSD_DEVICE ($OSD_DEVICE) doesn't exist !"
    exit 1
  fi

  if [ ! -e $OSD_BOOTSTRAP_KEYRING ]; then
    log "ERROR- $OSD_BOOTSTRAP_KEYRING must exist. You can extract it from your current monitor by running 'ceph auth get client.bootstrap-osd -o $OSD_BOOTSTRAP_KEYRING'"
    exit 1
  fi
  timeout 10 ceph ${CLI_OPTS} --name client.bootstrap-osd --keyring $OSD_BOOTSTRAP_KEYRING health || exit 1

  # search for some ceph metadata on the disk
  if [[ "$(parted --script ${OSD_DEVICE} print | egrep '^ 1.*ceph data')" ]]; then
    # parted will trigger udev, so make sure all current udev event be handled.
    udevadm settle
    log "It looks like ${OSD_DEVICE} is already an OSD"
    log "Checking if it belongs to this cluster"
    tmp_osd_mount="/var/lib/ceph/tmp/`echo $RANDOM`/"
    mkdir -p $tmp_osd_mount
    mount ${OSD_DEVICE}1 ${tmp_osd_mount}
    osd_cluster_fsid=`cat ${tmp_osd_mount}/ceph_fsid`
    umount ${tmp_osd_mount} && rmdir ${tmp_osd_mount}
    cluster_fsid=`ceph ${CLI_OPTS} --name client.bootstrap-osd --keyring $OSD_BOOTSTRAP_KEYRING fsid`
    if [ "${osd_cluster_fsid}" == "${cluster_fsid}" ]; then
      log "The OSD on ${OSD_DEVICE} belongs to this cluster, moving to activate phase"
      return
    fi
    log "This OSD belonged to another cluster: ${osd_cluster_fsid}. Current cluster fsid: ${cluster_fsid}"
  fi

  if [[ ${OSD_FORCE_ZAP} -eq 1 ]]; then
    log "Zapping ${OSD_DEVICE}"
    ceph-disk -v zap ${OSD_DEVICE}
  fi

  if [[ ${OSD_BLUESTORE} -eq 0 ]]; then
    ceph-disk -v prepare ${CLI_OPTS} --filestore ${OSD_DEVICE}
  elif [[ ${OSD_DMCRYPT} -eq 1 ]]; then
    # the admin key must be present on the node
    if [[ ! -e $ADMIN_KEYRING ]]; then
      log "ERROR- $ADMIN_KEYRING must exist; get it from your existing mon"
      exit 1
    fi
    # in order to store the encrypted key in the monitor's k/v store
    ceph-disk -v prepare ${CLI_OPTS} --journal-uuid ${OSD_JOURNAL_UUID} --lockbox-uuid ${OSD_LOCKBOX_UUID} --dmcrypt ${OSD_DEVICE} ${OSD_JOURNAL}
    echo "Unmounting LOCKBOX directory"
    # NOTE(leseb): adding || true so when this bug will be fixed the entrypoint will not fail
    # Ceph bug tracker: http://tracker.ceph.com/issues/18944
    DATA_UUID=$(blkid -o value -s PARTUUID ${OSD_DEVICE}1)
    umount /var/lib/ceph/osd-lockbox/${DATA_UUID} || true
  else
    ceph-disk -v prepare ${CLI_OPTS} --journal-uuid ${OSD_JOURNAL_UUID} ${OSD_DEVICE} ${OSD_JOURNAL}
  fi

  # watch the udev event queue, and exit if all current events are handled
  udevadm settle --timeout=600

  if [[ -n "${OSD_JOURNAL}" ]]; then
    wait_for_file ${OSD_JOURNAL}
    chown ceph. ${OSD_JOURNAL}
  else
    wait_for_file $(dev_part ${OSD_DEVICE} 2)
    chown ceph. $(dev_part ${OSD_DEVICE} 2)
  fi
}
