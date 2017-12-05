Useful commands for debugging
=============================

Basics
------

`helm install --debug --dry-run ...` will do a dry-run of the install operation and print out the generated templates, among other things. I suggest piping this to `less`.

`kubectl get all -n ceph -o wide` will list all the k8s resources ceph-helm has created (in the ceph namespace). `-n` is short for `--namespace`. `-o wide` is short for `--output=wide` and will list the nodes on which each pod is running.

Logs!
-----

`kubectl -n ceph logs <pod> -c <container>` will print out the logs for a specific container in a pod. Leaving off `-c <container>` will tell you what your options are for `<container>`. Useful.

`kubectl -n ceph describe <resource>` will print out a gold mine of information about the k8s resource. If what you want isn't in the logs, it's likely here.

If all above fails, ssh to a minion and run `journalctl -u kubelet` to give logs for the main k8s process on the node.
