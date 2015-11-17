#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

metatmp() {
  mkdir -p ${CLUSTER_NAME}-tmp
  echo "$(perl -pe 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : ""/eg' startup-scripts/${1})" > ${CLUSTER_NAME}-tmp/${2}
  echo ${CLUSTER_NAME}-tmp/${2}
}
export -f metatmp
