#!/bin/bash

set -e

# Set the script folder directory for navigation
script_dir="$(dirname -- "${BASH_SOURCE[0]}")"

SUBSCRIPTION=${1:-$SUBSCRIPTION}
if [ -z "$SUBSCRIPTION" ]; then
  read -r -p "Please enter a Subscription ID: " SUBSCRIPTION
fi

echo "Available Nexus Clusters for this subscription are:"
az networkcloud cluster list --sub "$SUBSCRIPTION" --query "sort_by([].{name:name, resourceGroup:resourceGroup, clusterVersion:clusterVersion, detailedStatus:detailedStatus, createdAt:systemData.createdAt}, &name)" -o table

CLUSTER_RG=${2:-$CLUSTER_RG}
if [ -z "$CLUSTER_RG" ]; then
  read -r -p "Enter the Nexus Cluster Resource Group: " CLUSTER_RG
fi

CLUSTER_NAME=$(az networkcloud cluster list --sub "$SUBSCRIPTION" -g "$CLUSTER_RG" --query "[].{name:name}" -o tsv)

# Check if the CLUSTER_NAME variable is empty
if [[ -z "$CLUSTER_NAME" ]]; then
  echo "No clusters found. Exiting."
  exit 1
fi

re="[[:space:]]+"
if [[ $CLUSTER_NAME =~ $re ]]; then
  az networkcloud cluster list --sub "$SUBSCRIPTION" -g "$CLUSTER_RG" --query "sort_by([].{name:name}, &name)" -o table
  read -r -p "More than one cluster in the Resource Group. Select the cluster you want to create alerts for: " CLUSTER_NAME
fi

CLUSTER_ID=$(az networkcloud cluster list --sub "$SUBSCRIPTION" -g "$CLUSTER_RG" --query "[].{id:id}" -o tsv)

ALERT_RG=${3:-$ALERT_RG}
if [ -z "$ALERT_RG" ]; then
  read -r -p "Please enter a Resource Group where you would want to deploy the alerts: " ALERT_RG
  if [ "$(az group exists --subscription "$SUBSCRIPTION" --name "$ALERT_RG")" = false ]; then
    echo "Resource Group '$ALERT_RG' not present in subscription '$SUBSCRIPTION'. Exiting."
    exit 1
  fi
fi

ACTION_GROUP_IDS=${4-$ACTION_GROUP_IDS}

echo ""
echo "Resource details for which alert will be created"
echo "Subscription:" "$SUBSCRIPTION"
echo "Cluster Resource Group:" "$CLUSTER_RG"
echo "Cluster name:" "$CLUSTER_NAME"
echo "Cluster ID:" "$CLUSTER_ID"
echo "Alert Resource Group:" "$ALERT_RG"
echo ""

for alert in "$script_dir"/nexusMetricAlerts/cluster/*.json; do
  az deployment group create --no-prompt --no-wait \
    --subscription "$SUBSCRIPTION" \
    --name "$(basename "${alert}" .json)_alert" \
    --resource-group "$ALERT_RG" \
    --template-file "$script_dir/templates/nexusMetricAlerts.bicep" \
    --parameters @"$alert" resourceIds="$CLUSTER_ID" actionGroupIds="$ACTION_GROUP_IDS"

  exit_code=$?

  if [[ $exit_code == 0 ]]; then
    echo "Alert deployment $(basename "${alert}" .json) succeeded for $CLUSTER_NAME"
  else
    echo "Alert deployment $(basename "${alert}" .json) failed for $CLUSTER_NAME"
  fi
done
