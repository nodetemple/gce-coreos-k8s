#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

source ./env.sh

gcloud config set project ${PROJECT}
gcloud config set compute/region ${REGION}
gcloud config set compute/zone ${ZONE}

for NODE_INDEX in {0..0}
do
  gcloud compute instances create etcd-${NODE_INDEX} \
    --tags "k8s-cluster,etcd-cluster,node-${NODE_INDEX}"
    --project ${PROJECT} \
    --zone ${ZONE} \
    --machine-type n1-standard-1 \
    --image-project coreos-cloud \
    --image coreos-alpha-845-0-0-v20151025 \
    --boot-disk-type pd-ssd \
    --boot-disk-size 30GB \
    --network ${NETWORK} \
    --can-ip-forward \
    --metadata-from-file user-data=./metadata/etcd.yaml \
    --no-scopes
done
