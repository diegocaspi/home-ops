# Runbook: Valkey Cluster Split After Pod Rescheduling

Applies to the `valkey-cluster` StatefulSet in the `ate-system` namespace on `nova`.

## Background

`valkey-cluster` is a 3-master/3-replica Valkey cluster deployed by the `substrate` HelmRelease (`kubernetes/apps/ate-system/base/substrate.yaml`). Each node persists its topology in `nodes.conf`, which stores peer addresses as pod IPs.

When pods reschedule (node reboot, evac, PVC rebind), they get new pod IPs. Each node keeps advertising its own current IP via the `--cluster-announce-ip $(POD_IP)` patch, but every node's `nodes.conf` still points its peers at the old, now-unassigned IPs. Connections to unassigned IPs time out instead of failing fast, so Valkey gossip never resumes and the cluster cannot self-heal.

## Symptoms

- `ate-api-server` pods crash-loop or log repeated `dial tcp 10.244.x.x:6379: i/o timeout` against raw pod IPs.
- Valkey logs show `Timeout connecting to the PRIMARY...` every ~60s.
- `CLUSTER INFO` reports `cluster_state:fail` and all slots in `pfail`.
- `CLUSTER NODES` lists peer IPs that no longer match current pod IPs (`kubectl get pods -o wide`).

## Diagnosis

Use the nova kubeconfig:

```sh
export KUBECONFIG=~/.kube/clusters/nova.yaml
```

Confirm the mismatch between topology and reality:

```sh
kubectl get pods -n ate-system -o wide | grep valkey
kubectl exec -n ate-system valkey-cluster-0 -- valkey-cli cluster info
kubectl exec -n ate-system valkey-cluster-0 -- valkey-cli cluster nodes
```

If `cluster_state:fail`, peers in `cluster nodes` differ from the IPs above, and a direct ping to a peer IP times out (`valkey-cli -h <peer-ip> ping`), this is the issue.

Confirm the announce-ip patch is intact on the StatefulSet (if missing, re-check the `substrate` HelmRelease postRenderers):

```sh
kubectl get sts -n ate-system valkey-cluster \
  -o jsonpath='{.spec.template.spec.containers[0].args}'
```

## Repair

Build the node ID → current IP mapping. Node IDs survive restarts, so match the IDs in `cluster nodes` (left column) against each pod's self-reported ID:

```sh
for p in 0 1 2 3 4 5; do
  echo -n "valkey-cluster-$p: "
  kubectl exec -n ate-system valkey-cluster-$p -- valkey-cli cluster myid
done
```

Then, from each pod, `CLUSTER MEET` every other pod's **current** IP. Handshakes refresh the stale address tables and gossip resumes; replicas re-attach to their masters on their own:

```sh
ips=(<ip-of-0> <ip-of-1> <ip-of-2> <ip-of-3> <ip-of-4> <ip-of-5>)

for s in 0 1 2 3 4 5; do
  for t in 0 1 2 3 4 5; do
    [ "$s" = "$t" ] && continue
    kubectl exec -n ate-system valkey-cluster-$s -- valkey-cli cluster meet "${ips[$t]}" 6379 > /dev/null
  done
done
```

`CLUSTER MEET` is idempotent and safe to re-run; only node IDs are matched, not addresses.

If a replica stays orphaned after gossip resumes (check `info replication` on each pod), re-point it explicitly by node ID:

```sh
kubectl exec -n ate-system valkey-cluster-<replica> -- \
  valkey-cli cluster replicate <master-node-id>
```

## Verification

```sh
kubectl exec -n ate-system valkey-cluster-0 -- valkey-cli cluster info
# expect: cluster_state:ok, cluster_slots_ok:16384
```

```sh
for p in 0 1 2 3 4 5; do
  kubectl exec -n ate-system valkey-cluster-$p -- \
    sh -c 'valkey-cli info replication | grep -E "^(role|master_host|connected_slaves)"'
done
# expect: 3 masters (connected_slaves:1), 3 slaves
```

Round-trip a write across slot ranges:

```sh
kubectl exec -n ate-system valkey-cluster-1 -- valkey-cli set runbook:ok live
kubectl exec -n ate-system valkey-cluster-1 -- valkey-cli get runbook:ok   # -> "live"
kubectl exec -n ate-system valkey-cluster-1 -- valkey-cli del runbook:ok
```

Watch the api-server stabilize:

```sh
kubectl get pods -n ate-system | grep api-server
kubectl logs -n ate-system deploy/ate-api-server-deployment --since=5m | grep -E "ERROR|WARN"
```

## Cleanup of stale client records

The outage can leave records that embed old IPs. One known case: the api-server syncer logs `update worker in store: ip is immutable` for workers whose IP changed while they were cached. Delete the affected record (slot ranges: master 1 → 5461–10922, master 3 → 10923–16383, master 4 → 0–5460) and let the syncer recreate it:

```sh
kubectl exec -n ate-system valkey-cluster-1 -- valkey-cli del "worker:<namespace>:<name>"
```

Only do this for records the syncer regenerates from Kubernetes. Never delete keys you cannot trace to a reconciler.

## Known limits

- This repair is manual. A durable fix would announce pod DNS hostnames (`cluster-announce-hostname` + `cluster-preferred-endpoint-type hostname`) instead of IPs, which requires a substrate chart-level change and possibly a cluster rebuild.
- If valkey data itself is lost or slot ranges diverge (masters disagree on slot ownership), this runbook does not apply — rebuild the cluster via the `valkey-cluster-init` job instead.
