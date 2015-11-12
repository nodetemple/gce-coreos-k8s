#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

source ./conf.sh

gcloud config set project ${PROJECT}
gcloud config set compute/region ${REGION}
gcloud config set compute/zone ${ZONE}

echo -e "- Setting up ${ETCD_NODES_AMOUNT} etcd nodes"

export ETCD_DISCOVERY_TOKEN=$(curl -s https://discovery.etcd.io/new?size=${ETCD_NODES_AMOUNT})
source ./func.sh
ETCD_META=$(metatmp etcd.yaml etcd-${ETCD_INDEX}.yaml)

gcloud compute instances create $(for ETCD_INDEX in $(seq 1 ${ETCD_NODES_AMOUNT}); do echo "${CLUSTER_NAME}-etcd-${ETCD_INDEX}"; done) \
  --tags "${CLUSTER_NAME}-etcd,${CLUSTER_NAME}" \
  --project ${PROJECT} \
  --network ${NETWORK} \
  --zone ${ZONE} \
  --machine-type n1-standard-1 \
  --image-project coreos-cloud \
  --image coreos-alpha-845-0-0-v20151025 \
  --boot-disk-type pd-ssd \
  --boot-disk-size 30GB \
  --can-ip-forward \
  --no-scopes \
  --metadata-from-file user-data=${ETCD_META}

gcloud compute firewall-rules create etcd-fw-rule
  --project ${PROJECT} \
  --network ${NETWORK} \
  --source-tags "${CLUSTER_NAME}-etcd" \
  --target-tags "${CLUSTER_NAME}-etcd" \
  --allow tcp:2379-2380

echo -e "- All tasks completed"
