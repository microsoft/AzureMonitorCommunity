#!/bin/bash

set -ex

# Set the script folder directory for navigation
script_dir="$(dirname -- "${BASH_SOURCE[0]}")"

RESOURCE_GROUP=${1:-$RESOURCE_GROUP}
if [ -z "$RESOURCE_GROUP" ]; then
  read -r -p "Enter Resource Group: " RESOURCE_GROUP
fi

WORKSPACE_LAW=${2:-$WORKSPACE_LAW}
if [ -z "$WORKSPACE_LAW" ]; then
  read -r -p "Enter Log Analytics workspace: " WORKSPACE_LAW
fi

AZ_LOCATION=${3:-$AZ_LOCATION}
if [ -z "$AZ_LOCATION" ]; then
  defaultLocation="$(az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$WORKSPACE_LAW" -o tsv --query location)"
  read -r -p "Enter Location for Alerts [$defaultLocation]: " AZ_LOCATION
  if [ -z "$AZ_LOCATION" ]; then
    AZ_LOCATION="$defaultLocation"
  fi
fi

ACTION_GROUP_IDS=${4-$ACTION_GROUP_IDS}

law_resource_id="$(az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$WORKSPACE_LAW" -o tsv --query id)"
for alert in "$script_dir"/scheduledQueryRules/*.json; do
  echo "Creating log query alert from: ${alert}"
  az deployment group create --no-prompt --no-wait \
    --name "$(basename "${alert}" .json)_alert" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$script_dir/templates/scheduledQueryRules.bicep" \
    --parameters @"$alert" resourceId="$law_resource_id" location="$AZ_LOCATION" actionGroupIds="$ACTION_GROUP_IDS"
done
for alert in "$script_dir"/scheduledQueryRules/*.json; do
  az deployment group wait --created \
    --name "$(basename "${alert}" .json)_alert" \
    --resource-group "$RESOURCE_GROUP" \
    --interval 10 --timeout 120
done
