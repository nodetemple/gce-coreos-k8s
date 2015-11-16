#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

source ./conf.sh

gcloud config set project ${PROJECT}
gcloud config set compute/region ${REGION}
gcloud config set compute/zone ${ZONE}

echo -e "- Setting up initial firewall rules"

gcloud compute firewall-rules create ${CLUSTER_NAME}-ssh \
  --network ${NETWORK} \
  --source-ranges "0.0.0.0/0" \
  --target-tags "${CLUSTER_NAME}" \
  --allow tcp:22

echo -e "- Setting up ${MASTER_NODES_AMOUNT} master nodes"

export ETCD_DISCOVERY_TOKEN=$(curl -s https://discovery.etcd.io/new?size=${MASTER_NODES_AMOUNT})
source ./func.sh
NODE_META=$(metatmp k8s-master.yaml ${CLUSTER_NAME}-k8s-master.yaml)

gcloud compute instances create $(for NODES_INDEX in $(seq 1 ${MASTER_NODES_AMOUNT}); do echo "${CLUSTER_NAME}-master-${NODES_INDEX}"; done) \
  --tags "${CLUSTER_NAME},${CLUSTER_NAME}-master" \
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
#https://github.com/kelseyhightower/coreos-ops-tutorial/blob/master/kube-kubelet.service

echo -e "- All tasks completed"
