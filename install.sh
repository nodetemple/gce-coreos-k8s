#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh

gcloud config set project ${PROJECT}
gcloud config set compute/region ${REGION}
gcloud config set compute/zone ${ZONE}

echo -e "- Initializing ${ETCD_NODES_AMOUNT} etcd nodes"

ETCD_ARRAY=()

for ETCD_INDEX in $(seq 1 ${ETCD_NODES_AMOUNT})
do
  ETCD_ARRAY+=("etcd${ETCD_INDEX}=http://${ETCD_NETWORK_PREFIX}.${ETCD_INDEX}:2380")
done

export ETCD_ENDPOINTS=$(IFS=,; echo "${ETCD_ARRAY[*]}")

for ETCD_INDEX in $(seq 1 ${ETCD_NODES_AMOUNT})
do
  export ETCD_INDEX

  echo -e "- Setting up etcd node #${ETCD_INDEX}"

  gcloud compute instances create etcd-${ETCD_INDEX} \
    --tags "k8s-cluster,etcd-cluster,etcd-${ETCD_INDEX}" \
    --project ${PROJECT} \
    --zone ${ZONE} \
    --machine-type n1-standard-1 \
    --image-project coreos-cloud \
    --image coreos-alpha-845-0-0-v20151025 \
    --boot-disk-type pd-ssd \
    --boot-disk-size 30GB \
    --network ${NETWORK} \
    --can-ip-forward \
    --no-scopes \
    --metadata user-data="$(perl -pe 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : ""/eg' metadata/etcd.yaml)"

  gcloud compute routes create etcd-${ETCD_INDEX} \
    --project ${PROJECT} \
    --network ${NETWORK} \
    --destination-range ${ETCD_NETWORK_PREFIX}.${ETCD_INDEX}/32 \
    --next-hop-instance etcd-${ETCD_INDEX} \
    --next-hop-instance-zone ${ZONE} \
    --priority 100
done
