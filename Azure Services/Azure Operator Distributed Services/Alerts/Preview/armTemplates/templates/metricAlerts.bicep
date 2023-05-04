@description('Allows creating an alert rule on a custom metric that isn\'t yet emitted, by causing the metric validation to be skipped.')
param skipMetricValidation bool = false

@description('Name of the alert')
@minLength(1)
param alertName string

@description('Description of alert')
param alertDescription string = ''

@description('Severity of alert {0,1,2,3,4}')
@allowed([
  0
  1
  2
  3
  4
])
param alertSeverity int = 3

@description('Specifies whether the alert is enabled')
param isEnabled bool = true

@description('Full Resource ID of the resource emitting the metric that will be used for the comparison. For example /subscriptions/00000000-0000-0000-0000-0000-00000000/resourceGroups/ResourceGroupName/providers/Microsoft.compute/virtualMachines/VM_xyz')
@minLength(1)
param resourceId string

@description('Namespace of the metric used in the comparison to activate the alert.')
@minLength(1)
param metricNamespace string

@description('Name of the metric used in the comparison to activate the alert.')
@minLength(1)
param metricName string

@description('Operator comparing the current value with the threshold value.')
@allowed([
  'Equals'
  'GreaterThan'
  'GreaterThanOrEqual'
  'LessThan'
  'LessThanOrEqual'
])
param operator string = 'GreaterThan'

@description('The threshold value at which the alert is activated.')
param threshold string = '0'

@description('How the data that is collected should be combined over time.')
@allowed([
  'Average'
  'Minimum'
  'Maximum'
  'Total'
  'Count'
])
param timeAggregation string = 'Average'

@description('Period of time used to monitor alert activity based on the threshold. Must be between one minute and one day. ISO 8601 duration format.')
@allowed([
  'PT1M'
  'PT5M'
  'PT15M'
  'PT30M'
  'PT1H'
  'PT6H'
  'PT12H'
  'PT24H'
])
param windowSize string = 'PT5M'

@description('how often the metric alert is evaluated represented in ISO 8601 duration format')
@allowed([
  'PT1M'
  'PT5M'
  'PT15M'
  'PT30M'
  'PT1H'
])
param evaluationFrequency string = 'PT1M'

@description('Array of dimension conditions objects:  { name, operator, values }')
param dimensions array = []

@description('Comma-separated list of resource IDs for action groups to be added as actions on the alert rule')
param actionGroupIds string = ''

resource alertName_resource 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertName
  location: 'global'
  tags: {}
  properties: {
    description: alertDescription
    severity: alertSeverity
    enabled: isEnabled
    scopes: [
      resourceId
    ]
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          skipMetricValidation: skipMetricValidation
          name: '1st criterion'
          metricNamespace: metricNamespace
          metricName: metricName
          dimensions: dimensions
          operator: operator
          threshold: threshold
          timeAggregation: timeAggregation
        }
      ]
    }
    actions: [for item in empty(actionGroupIds) ? [] : split(replace(actionGroupIds, ' ', ''), ','): {
      actionGroupId: item
    }]
  }
}
