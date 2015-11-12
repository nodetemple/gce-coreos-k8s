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

gcloud compute firewall-rules create ${CLUSTER_NAME}-etcd \
  --project ${PROJECT} \
  --network ${NETWORK} \
  --source-tags "${CLUSTER_NAME}-etcd" \
  --target-tags "${CLUSTER_NAME}-etcd" \
  --allow tcp:2380

gcloud compute firewall-rules create ${CLUSTER_NAME}-etcd-k8s \
  --project ${PROJECT} \
  --network ${NETWORK} \
  --source-tags "${CLUSTER_NAME}-etcd,${CLUSTER_NAME}-k8s-master" \
  --target-tags "${CLUSTER_NAME}-etcd" \
  --allow tcp:2379

export ETCD_DISCOVERY_TOKEN=$(curl -s https://discovery.etcd.io/new?size=${ETCD_NODES_AMOUNT})
source ./func.sh
ETCD_META=$(metatmp etcd.yaml ${CLUSTER_NAME}-etcd.yaml)

gcloud compute instances create $(for ETCD_INDEX in $(seq 1 ${ETCD_NODES_AMOUNT}); do echo "${CLUSTER_NAME}-etcd-${ETCD_INDEX}"; done) \
  --tags "${CLUSTER_NAME},${CLUSTER_NAME}-etcd" \
  --project ${PROJECT} \
  --zone ${ZONE} \
  --network ${NETWORK} \
  --machine-type n1-standard-1 \
  --image-project coreos-cloud \
  --image coreos-alpha-845-0-0-v20151025 \
  --boot-disk-type pd-ssd \
  --boot-disk-size 30GB \
  --can-ip-forward \
  --no-scopes \
  --metadata-from-file user-data=${ETCD_META}

gcloud compute addresses create ${CLUSTER_NAME}-lb-etcd-ip \
  --project ${PROJECT} \
  --global

gcloud compute http-health-checks create ${CLUSTER_NAME}-lb-etcd-check \
  --project ${PROJECT} \
  --port 2379 \
  --request-path "/version"

gcloud compute target-pools create ${CLUSTER_NAME}-lb-etcd-pool \
  --project ${PROJECT} \
  --region ${REGION} \
  --health-check ${CLUSTER_NAME}-lb-etcd-check \
  --session-affinity CLIENT_IP

gcloud compute forwarding-rules create ${CLUSTER_NAME}-lb-etcd-rule \
  --project ${PROJECT} \
  --region ${REGION} \
  --address "104.155.54.67" \ # TODO: get created static IP
  --ip-protocol TCP \
  --port-range 2379 \
  --target-pool ${CLUSTER_NAME}-lb-etcd-pool

echo -e "- Setting up k8s master node"

source ./func.sh
K8S_MASTER_META=$(metatmp k8s-master.yaml ${CLUSTER_NAME}-k8s-master.yaml)

gcloud compute instances create ${CLUSTER_NAME}-k8s-master \
  --tags "${CLUSTER_NAME},${CLUSTER_NAME}-k8s-master" \
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
  --metadata-from-file user-data=${K8S_MASTER_META}

echo -e "- All tasks completed"
