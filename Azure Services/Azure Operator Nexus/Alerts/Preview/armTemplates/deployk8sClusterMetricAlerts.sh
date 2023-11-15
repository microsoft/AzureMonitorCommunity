#!/bin/bash

set -e

# Set the script folder directory for navigation
script_dir="$(dirname -- "${BASH_SOURCE[0]}")"

SUBSCRIPTION=${1:-$SUBSCRIPTION}
if [ -z "$SUBSCRIPTION" ]; then
  read -r -p "Please enter a Subscription ID: " SUBSCRIPTION
fi

echo "Available connected kubernetes clusters for this subscription are:"
az connectedk8s list --subscription "$SUBSCRIPTION" --query "sort_by([].{name:name, resourceGroup:resourceGroup}, &name)" -o table

RESOURCE_GROUP=${2:-$RESOURCE_GROUP}
if [ -z "$RESOURCE_GROUP" ]; then
  read -r -p "Enter Resource Group of the Azure Connected Cluster: " RESOURCE_GROUP
fi

CLUSTER_NAME=${3:-$CLUSTER_NAME}
if [ -z "$CLUSTER_NAME" ]; then
  read -r -p "Enter Azure Connected Cluster Name: " CLUSTER_NAME
fi

ALERT_RG=${4:-$ALERT_RG}
if [ -z "$ALERT_RG" ]; then
  read -r -p "Please enter a Resource Group where you would want to deploy the alerts: " ALERT_RG
  if [ "$(az group exists --subscription "$SUBSCRIPTION" --name "$ALERT_RG")" = false ]; then
    echo "Resource Group '$ALERT_RG' not present in subscription '$SUBSCRIPTION'. Exiting."
    exit 1
  fi
fi

ACTION_GROUP_IDS=${5-$ACTION_GROUP_IDS}

connectedk8s_id="$(az connectedk8s show --subscription "$SUBSCRIPTION" -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" -o tsv --query id)"

for alert in "$script_dir"/k8sMetricAlerts/*.json; do
  echo "Creating metric alert from: ${alert}"
  az deployment group create --no-prompt --no-wait \
    --subscription "$SUBSCRIPTION" \
    --name "$(basename "${alert}" .json)_alert" \
    --resource-group "$ALERT_RG" \
    --template-file "$script_dir/templates/k8sMetricAlerts.bicep" \
    --parameters @"$alert" resourceId="$connectedk8s_id" actionGroupIds="$ACTION_GROUP_IDS"
done
for alert in "$script_dir"/k8sMetricAlerts/*.json; do
  az deployment group wait --created \
    --subscription "$SUBSCRIPTION" \
    --name "$(basename "${alert}" .json)_alert" \
    --resource-group "$ALERT_RG" \
    --interval 10 --timeout 120
done
