---
ArtifactType: ARM templates, scripts etc.
Documentation: Below
Language: bash etc.
Tags: lma,telemetry,networkcloud,nc,alerts
---

# Azure Operator Nexus (AzON) Logging, Monitoring, and Alerting

## Overview

This folder contains sample alert rules related to Azure Operator Nexus (AzON) Logging, Monitoring and Alerting.
It provides various ARM templates for use by customers to deploy selected resources.

### Prerequisites

The samples require one or more AzON resources (cluster/storage appliances) to be deployed and all of the necessary exporters, which will provide the metrics supporting these alert rules.

## Alert Rules

The Alerts ARM templates subfolder contains sample scripts, ARM templates and associated parameter files that you can run to create alert rules for the Nexus resources.

### Alert Rules Folder Structure

AzureMonitorCommunity repository path:  **`Alerts/Preview/armTemplates`**

- `deployActivityLogAlerts.sh` - Shell script utility for creating resource health alerts on Arc connected Kubernetes cluster
- `deployk8sClusterMetricAlerts.sh` - Shell script utility for creating metric alert rules on an Azure Connected Cluster resources
- `deployNexusClusterMetricAlerts.sh` - Shell script utility for creating metric alert rules on a Nexus Cluster resource
- `deployNexusStorageApplianceMetricAlerts.sh` - Shell script utility for creating metric alert rules on a Nexus StorageAppliance resource
- `/templates` - Folder contains ARM templates for use in deploying
  - `k8sMetricAlerts.bicep` - For Azure connected cluster metric alert rules
  - `nexusMetricAlerts.bicep` - For Nexus resource metric alert rules
[user-defined functions](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/functions/user-defined-functions)
used by queries in the parameter files to encapsulate some common approaches for
[querying Prometheus metrics](https://docs.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-log-query#query-prometheus-metrics-data)
scraped by Azure Container Insights.
- `/k8sMetricAlerts` - Folder contains parameter files. Each containing settings for sample metric alert rule
- `/nexusMetricAlerts`
  - `/cluster` - Folder contains parameter files. Each containing settings for sample metric alert rule
  - `/storageAppliance` - Folder contains parameter files. Each containing settings for sample metric alert rule

The following sections describe these resources in greater detail.  The sample alert rules you can deploy one at a time or use scripting to deploy multiple alert rules.

### Create Action Groups

When Azure Monitor data indicates that there might be a problem with your infrastructure or application, an alert is triggered.
Azure Monitor then use action groups to notify users about the alert and take an action. An Action Group is a collection of notification preferences that are defined by the owner of an Azure subscription.

Operators can create an Action Group that they deem suitable for their alert rules.
They can then provide that during deployment to the alert rules in the next steps.

Documentation to create Action Group: https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups

### Deployment

To use the Azure CLI to deploy an alert rule ARM template, sign in to the Azure CLI and set your subscription.

``` sh
    az login
    az account set -s "<SUBSCRIPTION_NAME_OR_ID>"
```
where
- **<SUBSCRIPTION_NAME_OR_ID>** = name or ID of subscription where deployment will be created

#### **Arc-Connected Metric Alert Rules**

You can apply Metric alert rules to an AzON Undercloud Arc-Connected Kubernetes Cluster that emits metrics that the alert rules monitor.
Deploy a single sample metric alert rule using the following command:

```sh
  az deployment group create \
    --name "<DEPLOYMENT_NAME>" \
    --subscription "<SUBSCRIPTION>" \
    --resource-group "<ALERT_RESOURCE_GROUP>" \
    --template-file "<PATH_TO_TEMPLATE_FILE>" \
    --parameters @"<PATH_TO_PARAMETER_FILE>" \
      resourceId="<CLUSTER_RESOURCE_ID" \
      actionGroupIds="<ACTION_GROUP_IDS>" \
      <PARAM_NAME>="<PARAM_VALUE>"...
```

where
- **<DEPLOYMENT_NAME>** = Name for the deployment
- **<SUBSCRIPTION>** = Name or ID of subscription where deployment will be created
- **<ALERT_RESOURCE_GROUP>** = The Resource Group where alerts will be deployed
- **<PATH_TO_TEMPLATE_FILE>** = Path to `templates/k8sMetricAlerts.bicep`
- **<PATH_TO_PARAMETER_FILE>** = Path to parameter file in `k8sMetricAlerts/` for alert rule to be created
- **<CLUSTER_RESOURCE_ID>** = Full Resource ID of the AzON cluster emitting the metric
- **<ACTION_GROUP_IDS>** = Optional comma-separated list of Action Group resource IDs to be associated to the alert
rule.
- **<PARAM_NAME>="<PARAM_VALUE>"** = Optional name/value pairs that can override other parameter file values

### Metric Alert Rule Deployment Scripting
A sample shell script (`deployk8sClusterMetricAlerts.sh`) that you can use to deploy all of the sample metric alert rules.
You can invoke the script with the following environment variables set or passed as arguments, if you didn't set a value the script will prompt for it.

- `SUBSCRIPTION` - The subscription where deployment will be created
- `RESOURCE_GROUP` - The Resource Group in which the AzON Undercloud Arc-Connected K8s Cluster resource is located
- `CLUSTER_NAME` - The name of the AzON Undercloud Arc-Connected K8s Cluster in the Resource Group that will emit the metrics
- `ALERT_RESOURCE_GROUP` - The Resource Group where alerts will be deployed
- `ACTION_GROUP_IDS` - *Optional* - Comma-separated list of action group resource IDs

You can run the script from the alert rules folder:

```sh
  ./deployk8sClusterMetricAlerts.sh $SUBSCRIPTION $RESOURCE_GROUP $CLUSTER_NAME $ALERT_RESOURCE_GROUP $ACTION_GROUP_IDS
```

*Note:
If container memory resource requests aren't specified, memoryRequestBytes metric won't be collected.
If container resource limits aren't specified, node’s capacity will be rolled-up as container’s limit.*

#### **Nexus Resource Metric Alert Rules**

You can apply metric alert rules to any Nexus resource that emits metrics that the alert rules monitor.
Deploy a single sample metric alert rule using the following command:

```sh
  az deployment group create \
    --name "<DEPLOYMENT_NAME>" \
    --subscription "<SUBSCRIPTION>" \
    --resource-group "<ALERT_RESOURCE_GROUP>" \
    --template-file "<PATH_TO_TEMPLATE_FILE>" \
    --parameters @"<PATH_TO_PARAMETER_FILE>" \
      resourceId="<RESOURCE_ID>" \
      actionGroupIds="<ACTION_GROUP_IDS>" \
      <PARAM_NAME>="<PARAM_VALUE>"...
```

where
- **<DEPLOYMENT_NAME>** = Name for the deployment
- **<SUBSCRIPTION>** = Name or ID of subscription where deployment will be created
- **<ALERT_RESOURCE_GROUP>** = The Resource Group where alerts will be deployed
- **<PATH_TO_TEMPLATE_FILE>** = Path to `templates/nexusMetricAlerts.bicep`
- **<PATH_TO_PARAMETER_FILE>** = Path to parameter file in `nexusMetricAlerts/` for alert rule to be created
- **<RESOURCE_ID>** = Full Resource ID of the Nexus resource emitting the metric
- **<ACTION_GROUP_IDS>** = Optional comma-separated list of Action Group resource IDs to be associated to the alert
rule.
- **<PARAM_NAME>="<PARAM_VALUE>"** = Optional name/value pairs that can override other parameter file values

### Metric Alert Rule Deployment Scripting
A sample shell script (`deployNexusClusterMetricAlerts.sh`) that you can use to deploy sample metric alert rules for cluster resources.
Similarly `deployNexusStorageApplianceMetricAlerts.sh` can be used to deploy metric alert rules for storage appliance resources.

You can run the script from the alert rules folder. The script will prompt for values required by the script.

```sh
  ./deployNexusClusterMetricAlerts.sh
```
OR

```sh
  ./deployNexusStorageApplianceMetricAlerts.sh
```
#### **Resource Health Alert Rules**

You can apply Resource health alert rules to an Arc-Connected K8s Cluster.
To deploy a single sample resource health alert rule using the following command:

```sh
  az deployment group create \
    --name "<DEPLOYMENT_NAME>" \
    --subscription "<SUBSCRIPTION>" \
    --resource-group "<ALERT_RESOURCE_GROUP>" \
    --template-file "<PATH_TO_TEMPLATE_FILE>" \
    --parameters @"<PATH_TO_PARAMETER_FILE>" \
      resourceGroup="<RESOURCE_GROUP>" \
      alertScope="subscriptions/<SUBSCRIPTION>" \
      actionGroupIds="<ACTION_GROUP_IDS>" \
      <PARAM_NAME>="<PARAM_VALUE>"...
```

where
- **<DEPLOYMENT_NAME>** = Name for the deployment
- **<SUBSCRIPTION>** = Name or ID of subscription where deployment will be created
- **<ALERT_RESOURCE_GROUP>** = The Resource Group where alerts will be deployed
- **<PATH_TO_TEMPLATE_FILE>** = Path to `templates/activityLogAlerts.bicep`
- **<PATH_TO_PARAMETER_FILE>** = Path to parameter file in `activityLogAlerts/` for alert rule to be created
- **<RESOURCE_GROUP>** = The Resource Group in which the AzON Undercloud Arc-Connected K8s Cluster resource is located
- **<ACTION_GROUP_IDS>** = Optional comma-separated list of Action Group resource IDs to be associated to the alert rule
- **<PARAM_NAME>="<PARAM_VALUE>"** = Optional name/value pairs, which can override other parameter file values

### Resource Health Alert Rule Deployment Scripting
A sample shell script (`deployActivityLogAlerts.sh`) that you can use to deploy all of the sample resource health alerts rules.
You can invoke the script with the following environment variables set or passed as arguments, if you didn't set a value
the script will prompt for it.

- `SUBSCRIPTION` - The subscription where deployment will be created
- `RESOURCE_GROUP` - The Resource Group in which the AzON Undercloud Arc-Connected K8s Cluster resource is located
- `ALERT_RESOURCE_GROUP` - The Resource Group where alerts will be deployed
- `ACTION_GROUP_IDS` - *Optional* - Comma-separated list of action group resource IDs

You can run the script from the alert rules folder:

```sh
  ./deployActivityLogAlerts.sh $SUBSCRIPTION $RESOURCE_GROUP $ALERT_RESOURCE_GROUP $ACTION_GROUP_IDS
```

## Testing

Alert rules may be viewed in the Azure portal when viewing a Resource Group by selecting *Alerts* from the left
navigation pane and then selecting *Alert rules* from the top of the Alerts view.
