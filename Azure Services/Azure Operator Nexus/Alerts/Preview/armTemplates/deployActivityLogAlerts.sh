#!/bin/bash

set -ex

# Set the script folder directory for navigation
script_dir="$(dirname -- "${BASH_SOURCE[0]}")"

RESOURCE_GROUP=${1:-$RESOURCE_GROUP}
if [ -z "$RESOURCE_GROUP" ]; then
  read -r -p "Enter Resource Group: " RESOURCE_GROUP
fi

ACTION_GROUP_IDS=${2-$ACTION_GROUP_IDS}

SUBSCRIPTION_ID=$(az account show --query id -o tsv)

alertScope="/subscriptions/$SUBSCRIPTION_ID"

for alert in "$script_dir"/activityLogAlerts/*.json; do
  echo "Creating activity log alert from: ${alert}"
  az deployment group create --no-prompt --no-wait \
    --name "$(basename "${alert}" .json)_alert" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$script_dir/templates/activityLogAlerts.bicep" \
    --parameters @"$alert" resourceGroup="$RESOURCE_GROUP" alertScope="$alertScope" actionGroupIds="$ACTION_GROUP_IDS"
done
for alert in "$script_dir"/activityLogAlerts/*.json; do
  az deployment group wait --created \
    --name "$(basename "${alert}" .json)_alert" \
    --resource-group "$RESOURCE_GROUP" \
    --interval 10 --timeout 120
done
