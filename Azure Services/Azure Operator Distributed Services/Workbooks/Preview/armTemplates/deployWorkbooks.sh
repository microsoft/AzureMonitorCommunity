#!/bin/bash

set -ex
# Set the script folder directory for navigation
script_dir="$(dirname -- "${BASH_SOURCE[0]}")"

#Check for parameter passed during invoking script, else take inputs from user through command line
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
  read -r -p "Enter Location for workbooks [$defaultLocation]: " AZ_LOCATION
  if [ -z "$AZ_LOCATION" ]; then
    AZ_LOCATION="$defaultLocation"
  fi
fi

echo "Azure Monitor - Creating WorkBook Templates and Instances"

#### Instances of the Workbooks are created in the same resource group as the Workbooks.
for instance in "${script_dir}"/templates/*.json; do
  echo "Deploying $(basename "${instance}")"
  az deployment group create --no-prompt --no-wait \
    --name "$(basename -s .json "${instance}")_Deploy_$(date +"%d-%b-%Y")" \
    --resource-group "${RESOURCE_GROUP}" \
    --template-file "$instance" \
    --parameters workspaceLAW="${WORKSPACE_LAW}" \
    --parameters workbookLocation="${AZ_LOCATION}"
done
for instance in "${script_dir}"/templates/*.json; do
  echo "Wait for $(basename "${instance}")"
  az deployment group wait --created \
    --name "$(basename -s .json "${instance}")_Deploy_$(date +"%d-%b-%Y")" \
    --resource-group "${RESOURCE_GROUP}" \
    --interval 10 --timeout 120
done

echo "Azure Monitor - Workbooks Templates and Instances created successfully"
