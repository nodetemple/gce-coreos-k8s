#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

source ./conf.sh

gcloud config set project ${PROJECT}
gcloud config set compute/region ${REGION}
gcloud config set compute/zone ${ZONE}

echo -e "- Setting up internal network"

gcloud compute networks create ${CLUSTER_NAME}-network \
  --range ${NETWORK_RANGE}

echo -e "- Setting up firewall rules"

gcloud compute firewall-rules create ${CLUSTER_NAME}-external-ssh \
  --network ${CLUSTER_NAME}-network \
  --allow tcp:22 \
  --source-ranges 0.0.0.0/0

gcloud compute firewall-rules create ${CLUSTER_NAME}-internal-icmp \
  --network ${CLUSTER_NAME}-network \
  --allow icmp \
  --source-ranges ${NETWORK_RANGE} \
  --target-tags ${CLUSTER_NAME}

gcloud compute firewall-rules create ${CLUSTER_NAME}-internal-etcd-peers \
  --network ${CLUSTER_NAME}-network \
  --allow tcp:2380 \
  --source-tags ${CLUSTER_NAME}-master \
  --target-tags ${CLUSTER_NAME}-master

gcloud compute firewall-rules create ${CLUSTER_NAME}-internal-etcd-clients \
  --network ${CLUSTER_NAME}-network \
  --allow tcp:2379 \
  --source-ranges ${NETWORK_RANGE} \
  --target-tags ${CLUSTER_NAME}-master

gcloud compute firewall-rules create ${CLUSTER_NAME}-internal-flannel-vxlan \
  --network ${CLUSTER_NAME}-network \
  --allow udp:8472 \
  --source-ranges ${NETWORK_RANGE} \
  --target-tags ${CLUSTER_NAME}

gcloud compute firewall-rules create ${CLUSTER_NAME}-internal-k8s-api \
  --network ${CLUSTER_NAME}-network \
  --allow tcp:443 \
  --source-ranges ${NETWORK_RANGE} \
  --target-tags ${CLUSTER_NAME}-master

echo -e "- Setting up routes"

for NODES_INDEX in $(seq 1 ${MASTER_NODES_AMOUNT})
do
  gcloud compute routes create ${CLUSTER_NAME}-master-${NODES_INDEX} \
    --network ${CLUSTER_NAME}-network \
    --priority 100 \
    --destination-range 10.2.0.${NODES_INDEX} \
    --next-hop-instance ${CLUSTER_NAME}-master-${NODES_INDEX}
done

echo -e "- Setting up ${MASTER_NODES_AMOUNT} master nodes"

gcloud compute instances create $(for NODES_INDEX in $(seq 1 ${MASTER_NODES_AMOUNT}); do echo "${CLUSTER_NAME}-master-${NODES_INDEX}"; done) \
  --tags ${CLUSTER_NAME},${CLUSTER_NAME}-master \
  --zone ${ZONE} \
  --network ${NETWORK} \
  --machine-type n1-standard-1 \
  --image-project coreos-cloud \
  --image coreos-alpha-870-2-0-v20151120 \
  --boot-disk-type pd-ssd \
  --boot-disk-size 30GB \
  --can-ip-forward \
  --scopes compute-ro \
  --metadata-from-file startup-script=startup-scripts/k8s-master.sh

#wget https://storage.googleapis.com/kubernetes-release/release/v1.1.1/bin/linux/amd64/kubelet

echo -e "- All tasks completed"
