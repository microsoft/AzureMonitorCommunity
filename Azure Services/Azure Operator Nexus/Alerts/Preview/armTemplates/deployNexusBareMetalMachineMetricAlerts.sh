#!/bin/bash

set -e

# Set the script folder directory for navigation
script_dir="$(dirname -- "${BASH_SOURCE[0]}")"

SUBSCRIPTION=${1:-$SUBSCRIPTION}
if [ -z "$SUBSCRIPTION" ]; then
  read -r -p "Please enter a Subscription ID: " SUBSCRIPTION
fi

REGION=${2:-$REGION}
if [ -z "$REGION" ]; then
  read -r -p "Please enter a Region where the resources exist: " REGION
fi

ALERT_RG=${3:-$ALERT_RG}
if [ -z "$ALERT_RG" ]; then
  read -r -p "Please enter a Resource Group where you would want to deploy the alerts: " ALERT_RG
  if [ "$(az group exists --subscription "$SUBSCRIPTION" --name "$ALERT_RG")" = false ]; then
    echo "Resource Group '$ALERT_RG' not present in subscription '$SUBSCRIPTION'. Exiting."
  fi
fi

SUBSCRIPTION_ID="/subscriptions/"$SUBSCRIPTION

ACTION_GROUP_IDS=${4-$ACTION_GROUP_IDS}

echo ""
echo "Resource details for which alert will be created"
echo "Subscription:" "$SUBSCRIPTION"
echo "Resource Location:" "$REGION"
echo "Alert Resource Group:" "$ALERT_RG"
echo ""

for alert in "$script_dir"/nexusMetricAlerts/bareMetalMachine/*.json; do
  az deployment group create --no-prompt --no-wait \
    --subscription "$SUBSCRIPTION" \
    --name "$(basename "${alert}" .json)_alert" \
    --resource-group "$ALERT_RG" \
    --template-file "$script_dir/templates/nexusMetricAlertsAcrossSubscription.bicep" \
    --parameters @"$alert" resourceIds="$SUBSCRIPTION_ID" targetResourceRegion="$REGION" actionGroupIds="$ACTION_GROUP_IDS"
done
for alert in "$script_dir"/nexusMetricAlerts/bareMetalMachine/*.json; do
  az deployment group wait --created \
    --subscription "$SUBSCRIPTION" \
    --name "$(basename "${alert}" .json)_alert" \
    --resource-group "$ALERT_RG" \
    --interval 10 --timeout 120
done
