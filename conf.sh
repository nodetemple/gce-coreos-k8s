#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

export PROJECT=nodetemple-main-project

export CLUSTER_NAME=demo-cluster

export NETWORK=${CLUSTER_NAME}-network
export NETWORK_RANGE=10.1.0.0/16

export REGION=europe-west1
export ZONE=${REGION}-d

export MASTER_NODES_AMOUNT=3

# The CIDR network to use for service cluster VIPs (Virtual IPs). Each service will be assigned a cluster IP out of this range. This must not overlap with any IP ranges assigned to the POD_NETWORK, or other existing network infrastructure. Routing to these VIPs is handled by a local kube-proxy service to each node, and are not required to be routable between nodes.
export SERVICE_IP_RANGE=10.2.0.0/24

# The VIP (Virtual IP) address of the Kubernetes API Service. If the SERVICE_IP_RANGE is changed above, this must be set to the first IP in that range.
export K8S_SERVICE_IP=10.2.0.1

# The VIP (Virtual IP) address of the cluster DNS service. This IP must be in the range of the SERVICE_IP_RANGE and cannot be the first IP in the range. This same IP must be configured on all worker nodes to enable DNS service discovery.
export DNS_SERVICE_IP=10.2.0.10

# The CIDR network to use for pod IPs. Each pod launched in the cluster will be assigned an IP out of this range. This network must be routable between all nodes in the cluster. In a default installation, the flannel overlay network will provide routing to this network.
export POD_NETWORK=10.3.0.0/16
