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

echo -e "- Setting up ${ETCD_NODES_AMOUNT} etcd nodes"

export ETCD_DISCOVERY_TOKEN=$(curl -s https://discovery.etcd.io/new?size=${ETCD_NODES_AMOUNT})

source ./func.sh
ETCD_META=$(metatmp etcd.yaml ${CLUSTER_NAME}-etcd.yaml)

gcloud compute instances create $(for ETCD_INDEX in $(seq 1 ${ETCD_NODES_AMOUNT}); do echo "${CLUSTER_NAME}-etcd-${ETCD_INDEX}"; done) \
  --tags "${CLUSTER_NAME},${CLUSTER_NAME}-etcd" \
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

gcloud compute instance-groups unmanaged create ${CLUSTER_NAME}-etcd-group \
  --zone ${ZONE}

gcloud compute instance-groups unmanaged add-instances ${CLUSTER_NAME}-etcd-group \
  --zone ${ZONE} \
  --instances $(for ETCD_INDEX in $(seq 1 ${ETCD_NODES_AMOUNT}); do echo "${CLUSTER_NAME}-etcd-${ETCD_INDEX}"; done) #if [ ${ETCD_INDEX} -gt 1 ]; then echo ","; fi;

gcloud compute firewall-rules create ${CLUSTER_NAME}-etcd-internal \
  --network ${NETWORK} \
  --source-tags "${CLUSTER_NAME}-etcd" \
  --target-tags "${CLUSTER_NAME}-etcd" \
  --allow tcp:2380

gcloud compute firewall-rules create ${CLUSTER_NAME}-etcd-lb-health \
  --network ${NETWORK} \
  --source-ranges 169.254.169.254/32 \
  --target-tags "${CLUSTER_NAME}-etcd" \
  --allow tcp:2379

gcloud compute firewall-rules create ${CLUSTER_NAME}-etcd-k8s \
  --network ${NETWORK} \
  --source-tags "${CLUSTER_NAME}-etcd,${CLUSTER_NAME}-k8s-master" \
  --target-tags "${CLUSTER_NAME}-etcd" \
  --allow tcp:2379

gcloud compute addresses create ${CLUSTER_NAME}-lb-etcd-ip \
  --region ${REGION}

export ETCD_LB_IP=$(gcloud compute addresses describe ${CLUSTER_NAME}-lb-etcd-ip --region ${REGION} --format json | jq --raw-output '.address')

gcloud compute http-health-checks create ${CLUSTER_NAME}-lb-etcd-check \
  --port 2379 \
  --request-path "/version"

gcloud compute target-pools create ${CLUSTER_NAME}-lb-etcd-pool \
  --region ${REGION} \
  --health-check ${CLUSTER_NAME}-lb-etcd-check

gcloud compute forwarding-rules create ${CLUSTER_NAME}-lb-etcd-rule \
  --region ${REGION} \
  --address ${ETCD_LB_IP} \
  --ip-protocol TCP \
  --port-range 2379 \
  --target-pool ${CLUSTER_NAME}-lb-etcd-pool

echo -e "- Setting up k8s master node"

source ./func.sh
K8S_MASTER_META=$(metatmp k8s-master.yaml ${CLUSTER_NAME}-k8s-master.yaml)

gcloud compute instances create ${CLUSTER_NAME}-k8s-master \
  --tags "${CLUSTER_NAME},${CLUSTER_NAME}-k8s-master" \
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

gcloud compute firewall-rules create ${CLUSTER_NAME}-flannel-udp-vxlan \
  --network ${NETWORK} \
  --source-tags "${CLUSTER_NAME}-etcd,${CLUSTER_NAME}-k8s-master" \
  --target-tags "${CLUSTER_NAME}-etcd,${CLUSTER_NAME}-k8s-master" \
  --allow udp:8472

echo -e "- All tasks completed"
