# Migration Tooling Script

Param(
    [Parameter(Mandatory=$True)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$True)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$True)]
    [string]$WorkspaceName,

    [Parameter(Mandatory=$True)]
    [string]$DCRName,

    [Parameter(Mandatory=$True)]
    [string]$Location,

    [Parameter(Mandatory=$False)]
    [string]$FolderPath = "."
)

class DCRPerformanceCounter
{
    [string]$name
    [string[]]$streams
    [int]$samplingFrequencyInSeconds
    [string[]]$counterSpecifiers
    [string] $platformType
}

class DCRWindowsEvent
{
    [string]$name
    [string[]]$streams
    [string[]]$xPathQueries
}

class DCRLinuxSyslog
{
    [string]$name
    [string[]]$streams
    [string[]]$facilityNames
    [string[]]$logLevels
}

function Get-UserWorkspace
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName
    )

    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $rgNameWorkspace -Name $workspaceName
    return $workspace
}

function Get-WorkspaceDataSources
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName,
        [ValidateSet("WindowsPerformanceCounter", "WindowsEvent", "LinuxSyslog", "LinuxPerformanceObject")]
        [Parameter(Mandatory=$true)][string] $DataSourceType
    )

    <#
    Current Supported List:
    WindowsPerformanceCounter
    WindowsEvent
    LinuxSyslog
    LinuxPerformanceObject

    Additional Values Supported by Get-AzOperationalInsightsDataSource:
    AzureAuditLog
    AzureActivityLog
    CustomLog
    ApplicationInsights
    #>

    $dataSources = Get-AzOperationalInsightsDataSource -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Kind $DataSourceType
    return $dataSources
}

function Get-DCRFromWorkspace
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName,
        [Parameter(Mandatory=$true)][string] $DCRName,
        [Parameter(Mandatory=$true)][string] $Location,
        [Parameter(Mandatory=$true)][string] $FolderPath
    )

    $windowsDCRTemplateParams = Get-DCRArmTemplateParams -DCRName "$($DCRName)-windows"
    $windowsDCRArmTemplate = Get-DCRArmTemplate -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Location $Location -PlatformType "Windows" -FolderPath $FolderPath
    
    $linuxDCRTemplateParams = Get-DCRArmTemplateParams -DCRName "$($DCRName)-linux"
    $linuxDCRArmTemplate = Get-DCRArmTemplate -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Location $Location -PlatformType "Linux" -FolderPath $FolderPath

    $currentDateTime = Get-Date -Format "MM-dd-yyyy-HH-mm-ss"
    if($windowsDCRArmTemplate.Count -gt 0)
    {
        $windowsDCRTemplateParams | Out-File "$($FolderPath)/dcr_windows_arm_template_$currentDateTime.parameters.json"
        $windowsDCRArmTemplate | Out-File "$($FolderPath)/dcr_windows_arm_template_$currentDateTime.json"
    }

    if($linuxDCRArmTemplate.Count -gt 0)
    {
        $linuxDCRTemplateParams | Out-File "$($FolderPath)/dcr_linux_arm_template_$currentDateTime.parameters.json"
        $linuxDCRArmTemplate | Out-File "$($FolderPath)/dcr_linux_arm_template_$currentDateTime.json"
    }
}

function Get-DCRArmTemplate
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName,
        [Parameter(Mandatory=$true)][string] $Location,
        [ValidateSet("Linux", "Windows")]
        [Parameter(Mandatory=$true)][string] $PlatformType,
        [Parameter(Mandatory=$true)][string] $FolderPath
    )

    $dcrJson = Get-DCRJson -ResourceGroupName $rgNameWorkspace -WorkspaceName $workspaceName -PlatformType $PlatformType
    
    #ARM Template File
    $schema = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    $contentVersion = "1.0.0.0"
    $paramName = "dataCollectionRules_name"
    $paramMetadata = @{
        "defaultValue" = "my_default_dcr-$($PlatformType.ToLower())";
        "type" = "String";
    }
    $parameters = @{
        "$($paramName)" = $paramMetadata;
    }
    $variables = @{}

    $result = @{}
    if($dcrJson.Count -gt 0)
    {
        $resources = @(
        [ordered]@{
            "type" = "Microsoft.Insights/dataCollectionRules";
            "apiVersion" = "2021-04-01";
            "name" = "[parameters('$($paramName)')]";
            "location" = $Location;
            "kind" = $PlatformType;
            "properties" = $dcrJson.properties
        })

        $dcrTemplate =
        [ordered]@{
            "`$schema" = $schema;
            "contentVersion" = $contentVersion;
            "parameters" = $parameters;
            "variables" = $variables;
            "resources" = $resources
        }

        # Regex handles replacing of escape characters that show up as hex codes in json output
        $result = ConvertTo-Json -InputObject $dcrTemplate -Depth 20
        <#
        $result = $result | %{
            [Regex]::Replace($_, 
            "\\u(?<Value>[a-zA-Z0-9]{4})", {
                param($m) ([char]([int]::Parse($m.Groups['Value'].Value,
                    [System.Globalization.NumberStyles]::HexNumber))).ToString() } )}
        #>
    }

    return $result
}

function Get-DCRArmTemplateParams
{
    param (
        [Parameter(Mandatory=$true)][string] $DCRName
    )
    #ARM Template Parameters File
    $schema = "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
    $contentVersion = "1.0.0.0"
    $paramName = "dataCollectionRules_name"
    $paramMetadata = @{
        "value" = "$DCRName";
    }
    $parameters = @{
        "$($paramName)" = $paramMetadata;
    }

    $dcrTemplateParams = 
    [ordered]@{
        "`$schema" = $schema;
        "contentVersion" = $contentVersion;
        "parameters" = $parameters
    }

    return ConvertTo-Json -Depth 5 $dcrTemplateParams
}

function Get-DCRJson
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName,
        [ValidateSet("Linux", "Windows")]
        [Parameter(Mandatory=$true)][string] $PlatformType
    )
    
    $dcrJson = @{}

    $dataSources = @{}
    $destinations = @{}
    $dataFlows = @{}

    $dataSources = Get-DataSources -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -PlatformType $PlatformType
    $destinations = Get-Destinations -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
    $dataFlows = Get-DataFlows -WorkspaceName $WorkspaceName -PlatformType $PlatformType

    if(-not (Get-DataSourceIsEmpty -DataSource $dataSources))
    {
        $properties = 
        [ordered]@{
            "dataSources" = $dataSources;
            "destinations" = $destinations;
            "dataFlows" = $dataFlows
        }

        $dcrJson.Add('properties', $properties)
    }

    return $dcrJson
}

function Get-DataSources
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName,
        [ValidateSet("Linux", "Windows")]
        [Parameter(Mandatory=$true)][string] $PlatformType
    )

    $perfCounterDataSources = @()
    $windowsEventDataSources = @()
    $linuxSyslogDataSources = @()

    if($PlatformType -eq "Linux")
    {
        $perfCounterDataSources = Get-LinuxPerformanceCountersInDCRFormat -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
        $linuxSyslogDataSources = Get-LinuxSyslogInDCRFormat -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
    }
    else
    {
        $perfCounterDataSources = Get-WindowsPerformanceCountersInDCRFormat -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
        $windowsEventDataSources = Get-WindowsEventsInDCRFormat -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
    }
    

    $dcrDataSources = 
    [ordered]@{
        "performanceCounters" = $perfCounterDataSources;
        "windowsEventLogs" = $windowsEventDataSources;
        "syslog" = $linuxSyslogDataSources
    }

    return $dcrDataSources
}

function Get-DataSourceIsEmpty
{
    param (
        [Parameter(Mandatory=$true)][hashtable] $DataSource
    )

    if($DataSource.Count -eq 0 -or ($DataSource["performanceCounters"].Count -eq 0 -and 
        $DataSource["windowsEventLogs"].Count -eq 0 -and $DataSource["syslog"].Count -eq 0))
    {
        return $true
    } 
    else
    {
        return $false
    }
}

function Get-WindowsPerformanceCountersInDCRFormat
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName
    )

    $dataSourceType = "WindowsPerformanceCounter"
    $workspaceDataSourceList = Get-AzOperationalInsightsDataSource -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Kind $dataSourceType
    $dcrPerfCounterStream = Get-DCRStream -DataSourceType $dataSourceType

    $dcrWindowsPerfCounterTable = [ordered]@{}
    $count = 1
    foreach($dataSource in $workspaceDataSourceList)
    {
        $properties = $dataSource.Properties
        $currentKey = [string]$properties.intervalSeconds
        if($dcrWindowsPerfCounterTable.Contains($currentKey))
        {
            $dcrWindowsPerfCounterTable[$currentKey].counterSpecifiers += "\$($properties.objectName)($($properties.instanceName))\$($properties.counterName)"
        }
        else
        {
            $newPerfCounter = New-Object DCRPerformanceCounter
            $newPerfCounter.name = "DataSource_$($dataSourceType)_$($count)"
            $newPerfCounter.counterSpecifiers = @("\$($properties.objectName)($($properties.instanceName))\$($properties.counterName)")
            $newPerfCounter.samplingFrequencyInSeconds = $properties.intervalSeconds
            $newPerfCounter.streams = $dcrPerfCounterStream
            $newPerfCounter.platformType = "Windows"
            $dcrWindowsPerfCounterTable.Add($currentKey, $newPerfCounter)
            $count += 1
        }
    }

    $dcrDataSourceList = @()
    foreach($key in $dcrWindowsPerfCounterTable.Keys)
    {
        $dcrDataSourceList += $dcrWindowsPerfCounterTable[$key]
    }

    return $dcrDataSourceList
}

function Get-LinuxPerformanceCountersInDCRFormat
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName
    )

    $dataSourceType = "LinuxPerformanceObject"
    $workspaceDataSourceList = Get-AzOperationalInsightsDataSource -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Kind $dataSourceType
    $dcrPerfCounterStream = Get-DCRStream -DataSourceType $dataSourceType

    $dcrLinuxPerfCounterTable = [ordered]@{}
    $count = 1
    foreach($dataSource in $workspaceDataSourceList)
    {
        $properties = $dataSource.Properties
        $currentKey = "$($properties.objectName)-$($properties.intervalSeconds)"
        $newPerfCounter = New-Object DCRPerformanceCounter
        $newPerfCounter.name = "DataSource_$($dataSourceType)_$($count)"
        $newPerfCounter.counterSpecifiers = @()
        $newPerfCounter.samplingFrequencyInSeconds = $properties.intervalSeconds
        $newPerfCounter.streams = $dcrPerfCounterStream
        $newPerfCounter.platformType = "Linux"
        
        foreach($counter in $properties.performanceCounters)
        {
            $newPerfCounter.counterSpecifiers += "\$($properties.objectName)($($properties.instanceName))\$($counter.counterName)"
        }

        $dcrLinuxPerfCounterTable.Add($currentKey, $newPerfCounter)
        $count += 1
    }

    $dcrDataSourceList = @()
    foreach($key in $dcrLinuxPerfCounterTable.Keys)
    {
        $dcrDataSourceList += $dcrLinuxPerfCounterTable[$key]
    }

    return $dcrDataSourceList
}

function Get-WindowsEventsInDCRFormat
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName
    )

    $dataSourceType = "WindowsEvent"
    $workspaceDataSourceList = Get-AzOperationalInsightsDataSource -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Kind $dataSourceType
    $dcrWindowsEventStream = Get-DCRStream -DataSourceType $dataSourceType

    $dcrWindowsEventTable = @{}
    $count = 1
    foreach($dataSource in $workspaceDataSourceList)
    {
        $properties = $dataSource.Properties
        if($properties.EventTypes.Length -gt 0)
        {
            $xPathQueryKey = Get-XPathQueryKey -WindowsEventProperties $properties

            if($dcrWindowsEventTable.Contains($xPathQueryKey))
            {
                $dcrWindowsEventTable[$xPathQueryKey].xPathQueries += "$($properties.eventLogName)!*$($xPathQueryKey)"
            }
            else
            {
                $newWindowsEvent = New-Object DCRWindowsEvent
                $newWindowsEvent.name = "DataSource_$($dataSourceType)_$($count)"
                $newWindowsEvent.xPathQueries = @("$($properties.eventLogName)!*$($xPathQueryKey)")
                $newWindowsEvent.streams = $dcrWindowsEventStream
                $dcrWindowsEventTable.Add($xPathQueryKey, $newWindowsEvent)
                $count += 1
            }
        }
    }

    $dcrDataSourceList = @()
    foreach($key in $dcrWindowsEventTable.Keys)
    {
        $dcrDataSourceList += $dcrWindowsEventTable[$key]
    }

    return $dcrDataSourceList
}

function Get-XPathQueryKey
{
    param (
        [Parameter(Mandatory=$true)][Microsoft.Azure.Commands.OperationalInsights.Models.PSWindowsEventDataSourceProperties] $WindowsEventProperties
    )

    #[System[(Level = 1 or Level = 2 or Level = 3)]]
    $eventTypeStr = ""
    foreach($type in $WindowsEventProperties.eventTypes)
    {   
        if($eventTypeStr.Length -gt 0)
        {
            $eventTypeStr += " or "
        }

        if($type.eventType.value__ -eq 0)
        {
            $eventTypeStr += "Level 1"
        }
        elseif($type.eventType.value__ -eq 1)
        {
            $eventTypeStr += "Level 2"
        }
        elseif($type.eventType.value__ -eq 2)
        {
            $eventTypeStr += "Level 3"
        }
    }

    return "[System[($($eventTypeStr))]]"
}

function Get-LinuxSyslogInDCRFormat
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName
    )

    $dataSourceType = "LinuxSyslog"
    $workspaceDataSourceList = Get-AzOperationalInsightsDataSource -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Kind $dataSourceType
    $dcrLinuxSyslogStream = Get-DCRStream -DataSourceType $dataSourceType

    $dcrLinuxSyslogTable = @{}
    $count = 1
    foreach($dataSource in $workspaceDataSourceList)
    {
        $properties = $dataSource.Properties
        if($properties.syslogSeverities.Length -gt 0)
        {
            $syslogLevels = Get-SyslogLevels -LinuxSyslogProperties $properties
            $logLevelsKey = $syslogLevels -join "-"
            if($dcrLinuxSyslogTable.Contains($logLevelsKey))
            {
                $dcrLinuxSyslogTable[$logLevelsKey].facilityNames += $properties.syslogName
            }
            else
            {
                $newLinuxSyslog = New-Object DCRLinuxSyslog
                $newLinuxSyslog.name = "DataSource_$($dataSourceType)_$($count)"
                $newLinuxSyslog.facilityNames = @($properties.syslogName)
                $newLinuxSyslog.logLevels = $syslogLevels
                $newLinuxSyslog.streams = $dcrLinuxSyslogStream
                $dcrLinuxSyslogTable.Add($logLevelsKey, $newLinuxSyslog)
                $count += 1
            }
        }
    }

    $dcrDataSourceList = @()
    foreach($key in $dcrLinuxSyslogTable.Keys)
    {
        $dcrDataSourceList += $dcrLinuxSyslogTable[$key]
    }

    return $dcrDataSourceList
}

function Get-SyslogLevels
{
    param (
        [Parameter(Mandatory=$true)][Microsoft.Azure.Commands.OperationalInsights.Models.PSLinuxSyslogDataSourceProperties] $LinuxSyslogProperties
    )

    $syslogLevels = @()
    foreach($severity in $LinuxSyslogProperties.SyslogSeverities)
    {
        switch($severity.Severity.value__)
        {
            0 { $syslogLevels += "Emergency"; Break }
            1 { $syslogLevels += "Alert"; Break }
            2 { $syslogLevels += "Critical"; Break }
            3 { $syslogLevels += "Error"; Break }
            4 { $syslogLevels += "Warning"; Break }
            5 { $syslogLevels += "Notice"; Break }
            6 { $syslogLevels += "Info"; Break }
            7 { $syslogLevels += "Debug" }
        }
    }

    return $syslogLevels
}

function Get-Destinations
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName
    )

    $workspace = Get-UserWorkspace -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName

    $laDest = 
    [ordered]@{
        "workspaceResourceId" = $workspace.ResourceId;
        "workspaceId" = $workspace.CustomerId;
        "name" = $workspace.Name;
    }

    $logAnalytics = @($laDest)
    $destinations = 
    @{
        "logAnalytics" = $logAnalytics;
    }
    return $destinations

}

function Get-DCRStream
{
    param (
        [ValidateSet("WindowsPerformanceCounter", "WindowsEvent", "LinuxSyslog", "LinuxPerformanceObject")]
        [Parameter(Mandatory=$true)][string] $DataSourceType
    )
    
    $stream = @()
    switch($DataSourceType)
    {
        "WindowsPerformanceCounter" { $stream += "Microsoft-Perf"; Break }
        "LinuxPerformanceObject" { $stream += "Microsoft-Perf"; Break }
        "WindowsEvent" { $stream += "Microsoft-WindowsEvent"; Break }
        "LinuxSyslog" { $stream += "Microsoft-Syslog" }
    }

    return $stream
}

function Get-DataFlows
{
    param (
        [Parameter(Mandatory=$true)][string] $WorkspaceName,
        [ValidateSet("Linux", "Windows")]
        [Parameter(Mandatory=$true)][string] $PlatformType
    )

    if($PlatformType -eq "Linux")
    {
        $perfCountersStream = Get-DCRStream -DataSourceType LinuxPerformanceObject
    }
    else
    {
        $perfCountersStream = Get-DCRStream -DataSourceType WindowsPerformanceCounter
    }
    
    $windowsEventsStream = Get-DCRStream -DataSourceType WindowsEvent
    $linuxSyslogStream = Get-DCRStream -DataSourceType LinuxSyslog

    $streams = @($perfCountersStream, $windowsEventsStream, $linuxSyslogStream)
    $destinations = @($WorkspaceName)
    $workspaceDataFlow = 
    [ordered]@{
        "streams" = $streams;
        "destinations" = $destinations;
    }
    
    $dataFlows = @($workspaceDataFlow)
    return $dataFlows
}


Connect-AzAccount
Select-AzSubscription -Subscription $subId

$rgNameWorkspace = 'rg-jamui-workspace'
$workspaceName = 'workspace-jamui-1'

Write-Output "Subscription Id: $($SubscriptionId)"
Write-Output "Resource Group: $($ResourceGroupName)"
Write-Output "Workspace Name: $($WorkspaceName)"

if(-not ($PSBoundParameters.ContainsKey('FolderPath')))
{
    $FolderPath = "."
}

if($FolderPath.LastIndexOf("/") -eq $FolderPath.Length-1)
{
    $FolderPath = $FolderPath.Substring(0, $FolderPath.Length-1)
}
Get-DCRFromWorkspace -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -DCRName $DCRName -Location $Location -FolderPath $FolderPath

