// Defines user-defined function definitions that are pre-pended to query parameter passed to the template so that they 
// are available for use by the query.
var udf = '''
// pquery_gauge queries metrics table for a prometheus gauge metric.
let pquery_gauge=(metrics_tbl:(*), metric_name:string, namespace_col:string='Namespace', name_col:string='Name', tags_col:string='Tags')
{
    metrics_tbl
    | extend Namespace = column_ifexists(namespace_col, ''), Name = column_ifexists(name_col, ''), Tags = column_ifexists(tags_col, '')
    | where Namespace == 'prometheus' and Name == metric_name
    | extend Labels = parse_json(Tags)
}
;
// pquery_counter queries metrics table for a prometheus counter metric and exposes the counter value change (DeltaVal) and time change
// in seconds (DeltaTimeSeconds) for each counter sample in the result.
let pquery_counter=(metrics_tbl:(*), metric_name:string, timegenerated_col:string='TimeGenerated', val_col:string='Val', tags_col:string='Tags')
{
    metrics_tbl
    | invoke pquery_gauge(metric_name)
    | extend TimeGenerated = column_ifexists(timegenerated_col, datetime(null)), Val = column_ifexists(val_col, real(null)), Tags = column_ifexists(tags_col, '')
    | sort by Tags, TimeGenerated asc
    | extend PrevTimeGenerated = iif(prev(Tags) != Tags, datetime(null), prev(TimeGenerated))
    | extend PrevVal = prev(Val)
    | where isnotnull(PrevTimeGenerated)
    | extend DeltaVal = iif(PrevVal > Val, Val, Val - PrevVal)
    | extend DeltaTimeSeconds = datetime_diff('Second', TimeGenerated, PrevTimeGenerated)
    | project-away PrevTimeGenerated, PrevVal
}
;
// pquery_histogram_buckets queries the histogram observation buckets for a metric basename and exposes the counter value change (bucketdiff) and 
// the upper inclusive bound (le) for each.
let pquery_histogram_buckets=(metrics_tbl:(*), metric_basename:string)
{
    metrics_tbl
    | invoke pquery_counter(strcat(metric_basename, '_bucket'))
    | extend le = todecimal(Labels.le)
    | project-rename bucketdiff = DeltaVal
}
;
// pquery_histogram_counts queries the histogram total count of events for a metric basename and exposes the counter value change (totaldiff).
let pquery_histogram_counts=(metrics_tbl:(*), metric_basename:string)
{
    metrics_tbl
    | invoke pquery_counter(strcat(metric_basename, '_count'))
    | project-rename totaldiff = DeltaVal
}
;
// pquery_histogram_quantile calculates the quantile for the specified percentile from buckets listed in a table.  For this function to work,
// the buckets in the metrics table must be sorted by the dimensions represented in the bucket and then by the le value in ascending order.
let pquery_histogram_quantile=(metrics_tbl:(*), percentile:real=0.99, le_col:string='le', buckettotal_col:string='buckettotal', total_col:string='total')
{
    metrics_tbl
    | serialize
    | where percentile between (0 .. 1)
    | extend le = column_ifexists(le_col, decimal(null)), buckettotal = column_ifexists(buckettotal_col, real(null)), total = column_ifexists(total_col, real(null))
    | extend prevle = iff(isnull(prev(le)) or prev(le) > le, decimal(0), prev(le))
    | extend prevbuckettotal = iff(prevle == 0, real(0), prev(buckettotal))
    | extend totalpercentile = percentile * total
    | where totalpercentile >= prevbuckettotal and totalpercentile < buckettotal
    | extend quantile = prevle + (((totalpercentile) - prevbuckettotal) * (le - prevle)) / (buckettotal - prevbuckettotal)
    | project-away le, buckettotal, total, prevle, prevbuckettotal, totalpercentile
}
;
let rate=(x:real, t:real) { x / t }
;
let percentage=(value:real, total:real) { 100 * rate(value, total) }
;
'''

@description('Name of the alert')
@minLength(1)
param alertName string

@description('Location of the alert')
@minLength(1)
param location string = resourceGroup().location

@description('Description of alert')
param alertDescription string = 'This is a metric alert'

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

@description('Specifies whether the alert will automatically resolve')
param autoMitigate bool = true

@description('Specifies whether to check linked storage and fail creation if the storage was not found')
param checkWorkspaceAlertsStorageConfigured bool = false

@description('Full Resource ID of the resource emitting the metric that will be used for the comparison. For example /subscriptions/00000000-0000-0000-0000-0000-00000000/resourceGroups/ResourceGroupName/providers/Microsoft.compute/virtualMachines/VM_xyz')
@minLength(1)
param resourceId string

@description('Name of the metric used in the comparison to activate the alert.')
@minLength(1)
param query string

@description('Name of the measure column used in the alert evaluation.')
param metricMeasureColumn string = ''

@description('Name of the resource ID column used in the alert targeting the alerts.')
param resourceIdColumn string

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

@description('The number of periods to check in the alert evaluation.')
param numberOfEvaluationPeriods int = 1

@description('The number of unhealthy periods to alert on (must be lower or equal to numberOfEvaluationPeriods).')
param minFailingPeriodsToAlert int = 1

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

// Pre-pend user-defined functions to query
var fullquery = '${udf}${query}'

resource alertName_resource 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: alertName
  location: location
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
      allOf: [
        {
          query: fullquery
          metricMeasureColumn: metricMeasureColumn
          resourceIdColumn: resourceIdColumn
          dimensions: dimensions
          operator: operator
          threshold: threshold
          timeAggregation: timeAggregation
          failingPeriods: {
            numberOfEvaluationPeriods: numberOfEvaluationPeriods
            minFailingPeriodsToAlert: minFailingPeriodsToAlert
          }
        }
      ]
    }
    autoMitigate: autoMitigate
    checkWorkspaceAlertsStorageConfigured: checkWorkspaceAlertsStorageConfigured
    actions: {
      actionGroups: empty(actionGroupIds) ? [] : split(replace(actionGroupIds, ' ', ''), ',')
    }
  }
}
