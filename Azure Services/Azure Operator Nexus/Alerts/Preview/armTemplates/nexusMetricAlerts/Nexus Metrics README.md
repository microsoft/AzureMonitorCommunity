---
ArtifactType: ARM templates, scripts etc.
Documentation: Below
Language: bash etc.
Tags: lma,telemetry,networkcloud,nc,aods,alerts
---

# Azure Operator Nexus (AzON) Logging, Monitoring, and Alerting

## Overview

This folder contains sample alert rules related to Azure Operator Nexus (AzON) Logging, Monitoring and Alerting.
It provides various ARM templates for use by customers to deploy selected resources.

### Prerequisites

The samples require one or more AzON instances connected with a Log Analytics Workspace. An AzON instance will deploy
all of the necessary Prometheus exporters, which will provide the metrics supporting these workbooks and alert rules.

## Alert Rules

The Alerts ARM templates subfolder contains sample scripts, ARM templates and associated parameter files that you can
run to create alert rules for the Nexus resources.

### Alert Rules Folder Structure

AzureMonitorCommunity repository path:  **`Alerts/Preview/armTemplates`**

- `deployNexusClusterMetricAlerts.sh` - Shell script utility for creating metric alert rules on an Nexus Cluster resources
- `deployNexusStorageApplianceMetricAlerts.sh` - Shell script utility for creating metric alert rules on an Nexus StorageAppliance resources
- `/templates` - Folder contains ARM templates for use in deploying
  - `metricAlerts.bicep` - For Metric alert rules
[user-defined functions](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/functions/user-defined-functions)
used by queries in the parameter files to encapsulate some common approaches for
[querying Prometheus metrics](https://docs.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-log-query#query-prometheus-metrics-data)
scraped by Azure Container Insights.
- `/metricAlerts` - Folder contains parameter files each containing settings for sample metric alert rule

The following sections describe these resources in greater detail.  The sample alert rules you can deploy one at a
time or use scripting to deploy multiple alert rules.

### Create Action Groups

When Azure Monitor data indicates that there might be a problem with your infrastructure or application, an alert is
triggered. Azure Monitor then use action groups to notify users about the alert and take an action. An Action Group is
a collection of notification preferences that are defined by the owner of an Azure subscription.

Operators can create an Action Group that they deem suitable for their alert rules. They can then provide that during
deployment to the alert rules in the next steps.

Documentation to create Action Group: https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups

### Deployment

To use the Azure CLI to deploy an alert rule ARM template, sign in to the Azure CLI and set your subscription.

``` sh
    az login
    az account set -s "<SUBSCRIPTION_NAME_OR_ID>"
```
where
- **<SUBSCRIPTION_NAME_OR_ID>** = name or ID of subscription where deployment will be created

#### **Metric Alert Rules**

You can apply Metric alert rules to any Nexus resource that emits metrics that the alert rules monitor. Deploy a
single sample metric alert rule using the following command:

```sh
  az deployment group create \
    --name "<DEPLOYMENT_NAME>" \
    --resource-group "<RESOURCE_GROUP>" \
    --template-file "<PATH_TO_TEMPLATE_FILE>" \
    --parameters @"<PATH_TO_PARAMETER_FILE>" \
      resourceId="<CLUSTER_RESOURCE_ID> or <STORAGEAPPLIANCE_RESOURCE_ID>" \
      actionGroupIds="<ACTION_GROUP_IDS>" \
      <PARAM_NAME>="<PARAM_VALUE>"...
```

where
- **<DEPLOYMENT_NAME>** = name for the deployment
- **<RESOURCE_GROUP>** = resource group where the alert rule will be created
- **<PATH_TO_TEMPLATE_FILE>** = path to `templates/metricAlerts.bicep`
- **<PATH_TO_PARAMETER_FILE>** = path to parameter file in `metricAlerts/` for alert rule to be created
- **<CLUSTER_RESOURCE_ID>** = Full Resource ID of the Nexus cluster emitting the metric
- **<STORAGEAPPLIANCE_RESOURCE_ID>** = Full Resource ID of the Nexus storage appliance emitting the metric
- **<ACTION_GROUP_IDS>** = Optional comma-separated list of Action Group resource IDs to be associated to the alert
rule.
- **<PARAM_NAME>="<PARAM_VALUE>"** = Optional name/value pairs that can override other parameter file values

### Metric Alert Rule Deployment Scripting
A sample shell script (`deployNexusClusterMetricAlerts.sh`) that you can use to deploy sample metric alert rules for cluster resources.
Similarly `deployNexusStorageApplianceMetricAlerts.sh` can be used to deploy metric alert rules for storage appliance resources.
You can invoke the script with the following environment variables set or passed as arguments, if you didn't set a value
the script will prompt for it.

- `RESOURCE_GROUP` - The Resource Group in which the Nexus Cluster resource is located
- `CLUSTER_NAME` - The name of the Nexus Cluster in the Resource Group that will emit the metrics
- `ACTION_GROUP_IDS` - *Optional* - Comma-separated list of action group resource IDs

## Testing

The workbooks provide you with an ability to filter the data across Timeframe, selected Nexus Cluster and the
Hostname. Make sure data is getting populated in these parameters to show the charts properly.

Alert rules may be viewed in the Azure portal when viewing a Resource Group by selecting *Alerts* from the left
navigation pane and then selecting *Alert rules* from the top of the Alerts view.
