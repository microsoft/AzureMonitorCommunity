#!/bin/bash

set -ex

# Set the script folder directory for navigation
script_dir="$(dirname -- "${BASH_SOURCE[0]}")"

RESOURCE_GROUP=${1:-$RESOURCE_GROUP}
if [ -z "$RESOURCE_GROUP" ]; then
  read -r -p "Enter Resource Group: " RESOURCE_GROUP
fi

CLUSTER_NAME=${2:-$CLUSTER_NAME}
if [ -z "$CLUSTER_NAME" ]; then
  read -r -p "Enter Azure Connected Cluster: " CLUSTER_NAME
fi

ACTION_GROUP_IDS=${3-$ACTION_GROUP_IDS}

connectedk8s_id="$(az connectedk8s show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" -o tsv --query id)"
for alert in "$script_dir"/metricAlerts/*.json; do
  echo "Creating metric alert from: ${alert}"
  az deployment group create --no-prompt --no-wait \
    --name "$(basename "${alert}" .json)_alert" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$script_dir/templates/metricAlerts.bicep" \
    --parameters @"$alert" resourceId="$connectedk8s_id" actionGroupIds="$ACTION_GROUP_IDS"
done
for alert in "$script_dir"/metricAlerts/*.json; do
  az deployment group wait --created \
    --name "$(basename "${alert}" .json)_alert" \
    --resource-group "$RESOURCE_GROUP" \
    --interval 10 --timeout 120
done
