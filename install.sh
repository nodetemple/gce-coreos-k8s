#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

source ./conf.sh

gcloud config set project ${PROJECT}
gcloud config set compute/region ${REGION}
gcloud config set compute/zone ${ZONE}

echo -e "- Setting up initial firewall rules"

gcloud compute networks create ${CLUSTER_NAME}-network \
  --range ${NETWORK_RANGE}

gcloud compute firewall-rules create ${CLUSTER_NAME}-allow-external-ssh \
  --network ${CLUSTER_NAME}-network \
  --allow tcp:22 \
  --source-ranges 0.0.0.0/0

gcloud compute firewall-rules create ${CLUSTER_NAME}-allow-internal-etcd-peers \
  --network ${CLUSTER_NAME}-network \
  --allow tcp:2380 \
  --source-tags ${CLUSTER_NAME}-master \
  --target-tags ${CLUSTER_NAME}-master

gcloud compute firewall-rules create ${CLUSTER_NAME}-allow-internal-etcd-clients \
  --network ${CLUSTER_NAME}-network \
  --allow tcp:2379,icmp \
  --source-ranges ${NETWORK_RANGE} \
  --target-tags ${CLUSTER_NAME}-master

gcloud compute firewall-rules create ${CLUSTER_NAME}-allow-internal-flannel-vxlan \
  --network ${CLUSTER_NAME}-network \
  --allow udp:8472 \
  --source-ranges ${NETWORK_RANGE} \
  --target-tags ${CLUSTER_NAME}

gcloud compute firewall-rules create ${CLUSTER_NAME}-allow-internal-k8s-api \
  --network ${CLUSTER_NAME}-network \
  --allow tcp:443 \
  --source-ranges ${NETWORK_RANGE} \
  --target-tags ${CLUSTER_NAME}-master

echo -e "- Setting up ${MASTER_NODES_AMOUNT} master nodes"

export ETCD_DISCOVERY_TOKEN=$(curl -s https://discovery.etcd.io/new?size=${MASTER_NODES_AMOUNT})
source ./func.sh
NODE_META=$(metatmp k8s-master.yaml ${CLUSTER_NAME}-k8s-master.yaml)

gcloud compute instances create $(for NODES_INDEX in $(seq 1 ${MASTER_NODES_AMOUNT}); do echo "${CLUSTER_NAME}-master-${NODES_INDEX}"; done) \
  --tags ${CLUSTER_NAME},${CLUSTER_NAME}-master \
  --zone ${ZONE} \
  --network ${NETWORK} \
  --machine-type n1-standard-1 \
  --image-project coreos-cloud \
  --image coreos-alpha-845-0-0-v20151025 \
  --boot-disk-type pd-ssd \
  --boot-disk-size 30GB \
  --can-ip-forward \
  --no-scopes \
  --metadata-from-file user-data=${NODE_META}

#wget https://storage.googleapis.com/kubernetes-release/release/v1.1.1/bin/linux/amd64/kubelet

echo -e "- All tasks completed"
