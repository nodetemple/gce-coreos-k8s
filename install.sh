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
--project ${PROJECT} \
--network ${NETWORK} \
--source-ranges "0.0.0.0/0" \
--target-tags "${CLUSTER_NAME}" \
--allow tcp:22

echo -e "- Setting up ${ETCD_NODES_AMOUNT} etcd nodes"

export ETCD_DISCOVERY_TOKEN=$(curl -s https://discovery.etcd.io/new?size=${ETCD_NODES_AMOUNT})
source ./func.sh
ETCD_META=$(metatmp etcd.yaml ${CLUSTER_NAME}-etcd.yaml)

gcloud compute firewall-rules create ${CLUSTER_NAME}-etcd \
  --project ${PROJECT} \
  --network ${NETWORK} \
  --source-tags "${CLUSTER_NAME}-etcd" \
  --target-tags "${CLUSTER_NAME}-etcd" \
  --allow tcp:2379-2380

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

echo -e "- All tasks completed"
