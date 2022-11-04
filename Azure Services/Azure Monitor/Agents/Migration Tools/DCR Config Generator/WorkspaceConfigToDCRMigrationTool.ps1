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
    [string]$FolderPath = ".",

    [Parameter(Mandatory=$False)]
    [switch]$GetDcrPayload
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

    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName
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

    $windowsDCRTemplateParams = Get-DCRBaseArmTemplateParams -DCRName "$($DCRName)-windows"
    $windowsDCRArmTemplate = Get-DCRArmTemplate -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Location $Location -PlatformType "Windows" -FolderPath $FolderPath
    
    $linuxDCRTemplateParams = Get-DCRBaseArmTemplateParams -DCRName "$($DCRName)-linux"
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

    $dcrJson = Get-DCRBaseJson -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -PlatformType $PlatformType
    
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
        
        $result = ConvertTo-Json -InputObject $dcrTemplate -Depth 20
    }

    return $result
}

function Get-DCRBaseArmTemplateParams
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

function Get-DCRBaseJson
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName,
        [ValidateSet("Linux", "Windows")]
        [Parameter(Mandatory=$true)][string] $PlatformType
    )
    
    $dcrJson = @{}

    $dataSources = Get-DataSources -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -PlatformType $PlatformType
    $destinations = Get-Destinations -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
    $dataFlows = [System.Collections.ArrayList]@(Get-DataFlows -WorkspaceName $WorkspaceName -PlatformType $PlatformType)

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
    
    # If the GetDcrPayloadJson parameter was set, output it to a file
    if ($GetDcrPayload)
    {
        $dcrJson | ConvertTo-Json -Depth 10 | Out-File "$($FolderPath)/dcr-payload-$($PlatformType).json"
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

    # Data sources are platform dependent
    # For Windows: perfCounters (WindowsPerfCounters), windowsEventLogs
    # For Linux: perfCounters (LinuxPerformanceObject), sysLog (LinuxSysLogs)
    $dcrDataSources = [ordered]@{}

    if($PlatformType -eq "Linux")
    {
        $perfCounterDataSources = Get-LinuxPerformanceCountersInDCRFormat -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
        $linuxSyslogDataSources = Get-LinuxSyslogInDCRFormat -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName

        if(($linuxSyslogDataSources -ne $null) -and ($linuxSyslogDataSources.GetType().Name -eq "DCRLinuxSyslog"))
        {
            $linuxSyslogDataSources = [System.Collections.ArrayList]@($linuxSyslogDataSources)
            $dcrDataSources["syslog"] = $linuxSyslogDataSources
        }
    }
    else
    {
        $perfCounterDataSources = Get-WindowsPerformanceCountersInDCRFormat -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
        $windowsEventDataSources = Get-WindowsEventsInDCRFormat -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName

        if(($windowsEventDataSources -ne $null) -and ($windowsEventDataSources.GetType().Name -eq "DCRWindowsEvent"))
        {
            $windowsEventDataSources = [System.Collections.ArrayList]@($windowsEventDataSources)
            $dcrDataSources["windowsEventLogs"] = $windowsEventDataSources
        }
    }

    if(($perfCounterDataSources -ne $null) -and ($perfCounterDataSources[0].GetType().Name -eq "DCRPerformanceCounter"))
    {
        
        $perfCounterDataSources = [System.Collections.ArrayList]@($perfCounterDataSources)
        $dcrDataSources["performanceCounters"] = $perfCounterDataSources
    }

    return $dcrDataSources
}

function Get-DataSourceIsEmpty
{
    param (
        [Parameter(Mandatory=$true)][hashtable] $DataSource
    )

    if($DataSource.Count -eq 0)   
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
            $newPerfCounter.name = "DS_$($dataSourceType)_$($count)"
            $newPerfCounter.counterSpecifiers = @("\$($properties.objectName)($($properties.instanceName))\$($properties.counterName)")
            $newPerfCounter.samplingFrequencyInSeconds = $properties.intervalSeconds
            $newPerfCounter.streams = $dcrPerfCounterStream
            $newPerfCounter.platformType = "Windows"
            $dcrWindowsPerfCounterTable.Add($currentKey, $newPerfCounter)
            $count += 1
        }
    }

    $dcrDataSourceList = [System.Collections.ArrayList]::new()
    foreach($key in $dcrWindowsPerfCounterTable.Keys)
    {
        $dcrDataSourceList.Add($dcrWindowsPerfCounterTable[$key]) | Out-Null
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
        $newPerfCounter.name = "DS_$($dataSourceType)_$($count)"
        $newPerfCounter.counterSpecifiers = @("")
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

    $dcrDataSourceList = [System.Collections.ArrayList]::new()
    foreach($key in $dcrLinuxPerfCounterTable.Keys)
    {
        $dcrDataSourceList.Add($dcrLinuxPerfCounterTable[$key]) | Out-Null
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
                $newWindowsEvent.name = "DS_$($dataSourceType)_$($count)"
                $newWindowsEvent.xPathQueries = @("$($properties.eventLogName)!*$($xPathQueryKey)")
                $newWindowsEvent.streams = $dcrWindowsEventStream
                $dcrWindowsEventTable.Add($xPathQueryKey, $newWindowsEvent)
                $count += 1
            }
        }
    }

    $dcrDataSourceList = [System.Collections.ArrayList]::new()
    foreach($key in $dcrWindowsEventTable.Keys)
    {
        $dcrDataSourceList.Add($dcrWindowsEventTable[$key]) | Out-Null
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
                $newLinuxSyslog.name = "DS_$($dataSourceType)_$($count)"
                $newLinuxSyslog.facilityNames = @($properties.syslogName)
                $newLinuxSyslog.logLevels = $syslogLevels
                $newLinuxSyslog.streams = $dcrLinuxSyslogStream
                $dcrLinuxSyslogTable.Add($logLevelsKey, $newLinuxSyslog)
                $count += 1
            }
        }
    }

    $dcrDataSourceList = [System.Collections.ArrayList]::new()
    foreach($key in $dcrLinuxSyslogTable.Keys)
    {
        $dcrDataSourceList.Add($dcrLinuxSyslogTable[$key]) | Out-Null
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

function ConnectToAz {
    param (
        # This helps tie the AzContext to a specific Subscription 
        [Parameter(Mandatory=$true)][string] $SubscriptionId
    )

    $azContext = Get-AzContext

    if ($azContext -ne $null)
    {
        Write-Output "You are already logged into Azure"

        $currentAzContextSubId = $azContext.Subscription.Id

        if($currentAzContextSubId -ne $SubscriptionId)
        {
            #Switching to a different Subscription
            Set-AzContext -Subscription $SubscriptionId
        }
    }
    else 
    {
        try 
        {
            Write-Output "Connecting to Azure..."
            Connect-AzAccount | Out-Null
            Set-AzContext -Subscription $SubscriptionId | Select-Object -Property Name, Account, Environment, Subscription | Format-List
            Write-Output "Successfully connected to Azure"
        }
        catch 
        {
            Write-Output "Error connection to Azure. Please try again!"
            Exit
        }
    }
}

<# ====================================== #>
# Output Folder
if(-not ($PSBoundParameters.ContainsKey('FolderPath')))
{
    $FolderPath = "."
}

if($FolderPath.LastIndexOf("/") -eq $FolderPath.Length-1)
{
    $FolderPath = $FolderPath.Substring(0, $FolderPath.Length-1)
}

# User parameters selections
Write-Output "You entered:"
Write-Output ""
Write-Output "Subscription Id     $($SubscriptionId)"
Write-Output "ResourceGroupName   $($ResourceGroupName)"
Write-Output "Workspace Name      $($WorkspaceName)"
Write-Output ""

# User authentication
$WarningPreference = 'SilentlyContinue'
ConnectToAz -SubscriptionId $SubscriptionId

# Entry point of the script
Get-DCRFromWorkspace -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -DCRName $DCRName -Location $Location -FolderPath $FolderPath

# End of script
Write-Output ""
Write-Output "Success!"
Write-Output "Check your output folder! (Relative path:  $($FolderPath))"
