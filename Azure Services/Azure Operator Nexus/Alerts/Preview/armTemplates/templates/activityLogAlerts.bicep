@description('Comma-separated list of action group resource IDs to be added as actions on the alert rule')
param actionGroupIds string = ''

@description('Description of alert')
param alertDescription string = ''

@description('Name of the alert')
@minLength(1)
param alertName string

@description('Scope of the alert. For example /subscriptions/00000000-0000-0000-0000-000000000000')
@minLength(1)
param alertScope string

@description('Specifies whether the alert is enabled')
param isEnabled bool = true

@description('Resource group of the alert')
@minLength(1)
param resourceGroup string

@description('Resource type of the alert')
@minLength(1)
param resourceType string

resource alertName_resource 'microsoft.insights/activitylogalerts@2020-10-01' = {
  name: alertName
  location: 'global'
  properties: {
    enabled: isEnabled
    description: alertDescription
    scopes: [
      alertScope
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'ResourceHealth'
        }
        {
          anyOf: [
            {
              field: 'properties.cause'
              equals: 'PlatformInitiated'
            }
          ]
        }
        {
          anyOf: [
            {
              field: 'properties.currentHealthStatus'
              equals: 'Degraded'
            }
            {
              field: 'properties.currentHealthStatus'
              equals: 'Unavailable'
            }
          ]
        }
        {
          anyOf: [
            {
              field: 'status'
              equals: 'Active'
            }
          ]
        }
        {
          anyOf: [
            {
              field: 'properties.previousHealthStatus'
              equals: 'Available'
            }
          ]
        }
        {
          anyOf: [
            {
              field: 'resourceGroup'
              equals: resourceGroup
            }
          ]
        }
        {
          anyOf: [
            {
              field: 'resourceType'
              equals: resourceType
            }
          ]
        }
      ]
    }
    actions: {
      actionGroups: [for item in empty(actionGroupIds) ? [] : split(replace(actionGroupIds, ' ', ''), ','): {
        actionGroupId: item
      }]
    }
  }
}
