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

RG_FLAG=${3:-$RG_FLAG}
if [ -z "$RG_FLAG" ]; then
  read -r -p "Please confirm if [$RESOURCE_GROUP] a Cluster Manager Resource Group [Y/N]: " RG_FLAG
fi

AZ_LOCATION=${4:-$AZ_LOCATION}
if [ -z "$AZ_LOCATION" ]; then
  defaultLocation="$(az monitor log-analytics workspace show -g "$RESOURCE_GROUP" -n "$WORKSPACE_LAW" -o tsv --query location)"
  read -r -p "Enter Location for workbooks [$defaultLocation]: " AZ_LOCATION
  if [ -z "$AZ_LOCATION" ]; then
    AZ_LOCATION="$defaultLocation"
  fi
fi

### Check for Resource Group Type and move templates in temp folder for deployment in correct Resource Group

TEMP_DIR="${script_dir}"/templates/TEMP/
if [ ! -d "${TEMP_DIR}" ]; then
  echo -e "Creating temp directory (${TEMP_DIR})"
  mkdir -p "${TEMP_DIR}"
else
  rm -rf "${script_dir}"/templates/TEMP/
  mkdir -p "${TEMP_DIR}"
fi

for instance in "${script_dir}"/templates/*.json; do
  name="$(basename "${instance}")"
  if [[ "${RG_FLAG^^}" == "Y" && "${name}" == "hwvalidation.json" ]]; then
    cp "$instance" "${script_dir}"/templates/TEMP/
  elif [[ "${RG_FLAG^^}" == "N" && "${name}" != "hwvalidation.json" ]]; then
    cp "$instance" "${script_dir}"/templates/TEMP/
  else
    echo "[$RESOURCE_GROUP] type not entered "
  fi
done

echo "Azure Monitor - Creating WorkBook Templates and Instances"

#### Instances of the Workbooks are created in the same resource group as the Workbooks.
for instance in "${script_dir}"/templates/TEMP/*.json; do
  echo "Deploying $(basename "${instance}")"
  az deployment group create --no-prompt --no-wait \
    --name "$(basename -s .json "${instance}")_Deploy_$(date +"%d-%b-%Y")" \
    --resource-group "${RESOURCE_GROUP}" \
    --template-file "$instance" \
    --parameters workspaceLAW="${WORKSPACE_LAW}" \
    --parameters workbookLocation="${AZ_LOCATION}"
done
for instance in "${script_dir}"/templates/TEMP/*.json; do
  echo "Wait for $(basename "${instance}")"
  az deployment group wait --created \
    --name "$(basename -s .json "${instance}")_Deploy_$(date +"%d-%b-%Y")" \
    --resource-group "${RESOURCE_GROUP}" \
    --interval 10 --timeout 120
done

echo "Azure Monitor - Workbooks Templates and Instances created successfully"

rm -rf "${script_dir}"/templates/TEMP/
