#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

IP_ADDR=$(/usr/bin/curl -s -H "Metadata-Flavor: Google" "http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip")

GCE_TOKEN=$(curl -s -H "Metadata-Flavor: Google" "http://metadata/computeMetadata/v1/instance/service-accounts/default/token" | jq -r ".access_token")

MASTER_ADDRS=$(/usr/bin/curl -s -H "Authorization":"Bearer ${GCE_TOKEN}" "https://www.googleapis.com/compute/v1/projects/nodetemple-main-project/zones/europe-west1-d/instances?filter=name+eq+'.*-master-.*'&fields=items%2FnetworkInterfaces%2FnetworkIP" | jq -r ".items[].networkInterfaces[0].networkIP" | paste -s -d ',')

cat >/etc/systemd/system/nodetemple-master.service <<EOF
[Service]
ExecStartPre=-
ExecStart=/usr/bin/echo "${MASTER_ADDRS}" > /root/etcd-masters
Restart=always
RestartSec=5
StartLimitInterval=0
EOF

systemctl start nodetemple-master.service
