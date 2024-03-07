<#
File: WorkspaceConfigToDCRMigrationTool.ps1
Author: Azure Monitor Control Service
Email: amcsdev@microsoft.com
Description: This module contains code to help our customers migrate from MMA based configurations to AMA based configurations (DCR)
Version: 1.0.0

Copyright (c) November 2023 Microsoft
#>

# All the following variables are global
param(
    [Parameter(Mandatory=$True)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$True)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$True)]
    [string]$WorkspaceName,

    [Parameter(Mandatory=$True)]
    [string]$DcrName,

    [Parameter(Mandatory=$False)]
    [string]$OutputFolder
)

#region Custom Type Definitions
# 1. Data Sources
class DCRPerfCounterDataSource
{
    [string]$name
    [string[]]$streams
    [int]$samplingFrequencyInSeconds
    [string[]]$counterSpecifiers
}
class DCRWindowsEventLogDataSource
{
    [string]$name
    [string[]]$streams
    [string[]]$xPathQueries
}

class DCRSyslogDataSource
{
    [string]$name
    [string[]]$streams
    [string[]]$facilityNames
    [string[]]$logLevels
}

#endregion

#region Utility functions

<#
.DESCRIPTION
    This function ensures the output folder provided by the user is valid
#>
function Set-ValidateOutputFolder
{
    Write-Host
    if ("" -eq $OutputFolder)
    {
        $OutputFolder = $PWD.Path
        Write-Host "Info: No output folder provided. Defaulting to the current working directory: $OutputFolder" -ForegroundColor Cyan
        $state.runtime["outputFolder"] = $OutputFolder
    }
    else {
        try {
            $OutputFolder = Convert-Path $OutputFolder -ErrorAction Stop
            $state.runtime["outputFolder"] = $OutputFolder
        }
        catch {
            Write-Host "Invalid output folder: $PSItem. Please try again" -ForegroundColor Red
            Write-Host
            Exit
        }
    }
}

<#
.DESCRIPTION
    This function authenticates the user to Azure and ties the auth context to a specific Subscription
#>
function Set-AzSubscriptionContext {
    param (
        # This helps tie the AzContext to a specific Subscription 
        [Parameter(Mandatory=$true)][string] $SubscriptionId
    )

    Write-Host

    $azContext = Get-AzContext

    if ($null -ne $azContext)
    {
        Write-Host "Info: You are already logged into Azure" -ForegroundColor Green

        $currentAzContextSubId = $azContext.Subscription.Id

        if($currentAzContextSubId -ne $SubscriptionId)
        {
            Write-Host "Info: Switching to a different subscription context" -ForegroundColor Cyan
            
            try {
                Set-AzContext -Subscription $SubscriptionId -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Host "Error in setting the new Az Context: $PSItem" -ForegroundColor Red
                Write-Host
                Exit
            }

            Write-Host "Old subscription Id: $($currentAzContextSubId)" -ForegroundColor Cyan
            Write-Host "New Subscription Id: $($SubscriptionId)" -ForegroundColor Green
        }
    }
    else 
    {
        try 
        {
            Write-Host "Connecting to Azure..." -ForegroundColor DarkYellow
            Connect-AzAccount | Out-Null
            Set-AzContext -Subscription $SubscriptionId | Out-Null
            Write-Host "Successfully connected to Azure" - ForegroundColor Green
        }
        catch 
        {
            Write-Host "Error connection to Azure. Please try again!" -ForegroundColor Red
            Exit
        }
    }
}

<#
.DESCRIPTION
    This function generates the base arm template object that will be modified
#>
function Get-BaseArmTemplate
{
    $dcrResourceDef = [ordered]@{
        "type" = "Microsoft.Insights/dataCollectionRules"
        "apiVersion" = "2022-06-01" # Using the latest api version
        "name" = "[parameters('dcrName')]"
        "location" = "[parameters('dcrLocation')]"
        "properties" = [ordered]@{
            "description" = "A Data Collection Rule"
            "dataSources" = [ordered]@{
            }
            "destinations" = [ordered]@{
                "logAnalytics" = @(
                    [ordered]@{
                        "workspaceResourceId" = "[parameters('logAnalyticsWorkspaceArmId')]"
                        "name" = "myloganalyticsworkspace"
                    }
                )
            }
            "dataFlows" = @(
                [ordered]@{
                    "streams" = @()
                    "destinations" = @("myloganalyticsworkspace")
                }
            )
        }
    }

    $armTemplate = [ordered]@{
        "`$schema" = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
        "contentVersion" = "1.0.0.0"
        "parameters" = [ordered]@{
            "dcrName" = [ordered]@{
                "type" = "string"
                "defaultValue" = $DcrName
                "metadata" = [ordered]@{
                    "description" = "The name of the Data Collection Rule as it will appear in the portal."
                }
            }
            "dcrLocation" = [ordered]@{
                "type" = "string"
                "defaultValue" = $Location #This should be the same as the one of the LAW referenced in `Destinations`
                "metadata" = [ordered]@{
                    "description" = "The location of the DCR. DCR is a regional resource."
                }
            }
            "logAnalyticsWorkspaceArmId" = [ordered]@{
                "type" = "string"
                "defaultValue" = "/subscriptions/$($SubscriptionId)/resourcegroups/$($ResourceGroupName)/providers/microsoft.operationalinsights/workspaces/$($WorkspaceName)"
                "metadata" = [ordered]@{
                    "description" = "The ARM Id of the log analytics workspace destination"
                }
            }
        }
        "resources" = @($dcrResourceDef)
    }

    return $armTemplate
}

<#
.DESCRIPTION
    Generates empty DCR arm templated for each output type
#>
function Set-InitializeOutputs
{
    $state["outputs"] = @{
        "windows" = Get-BaseArmTemplate
        "linux" = Get-BaseArmTemplate
        "extensions" = Get-BaseArmTemplate
        "iis" = Get-BaseArmTemplate
        "cls" = @() # An array of Custom Logs DCR Arm templates
    }
}

<#
.DESCRIPTION
    Does a get call on the Log Analytics workspace provided by the user
    Information retrieved will be used later
#>
function Get-UserLogAnalyticsWorkspace
{
    Write-Host
    Write-Host 'Info: Fetching the specified Log Analytics Workspace details' -ForegroundColor Cyan

    # The $Workspace Name in this context in case insensitive
    try {
        $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -ErrorAction Stop
        $workspace | Out-Null
    }
    catch {
        Write-Host "$PSItem" -ForegroundColor Red
        Write-Host
        Exit
    }
    
    Write-Host 'Info: Successfully retrieved the LAW details' -ForegroundColor Green
    $state.runtime["workspace"] = $workspace
    $state.runtime["dcrLocation"] = $workspace.Location
}

<#
.DESCRIPTION
    Checks and parses the Windows Perf Counters on the workspace
#>
function Get-WindowsPerfCountersDataSource
{
    <#
    .DESCRIPTION
        This function applies Modifications if necessary to the counterSpecifier
    #>
    function Get-ValidatedWindowsCounterSpecifier
    {
        param(
            [Parameter(Mandatory=$true)][string] $counterSpecifier
        )
        # Case 0
        # \Memory(*)\Counter Name is an invalid perfCounter
        # Whenever we encounter it, transform it to \Memory\CounterName (with no instance specified)
        $counterSpecifier = $counterSpecifier.replace("Memory(*)", "Memory")
        return $counterSpecifier
    }

    $windowsPerfCounters = Get-AzOperationalInsightsDataSource -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Kind "WindowsPerformanceCounter"
    if ($null -eq $windowsPerfCounters)
    {
        Write-Host "Info: Windows Performance Counters is not enabled on the workspace" -ForegroundColor Yellow
    }
    else {
        Write-Host "Info: Windows Performance Counters is enabled on the workspace" -ForegroundColor Green
        $state.runtime.dataSourcesCount += 1
        $state.runtime.dcrTypesEnabled.windows = $true

        # Windows DCR output updates
        $state.outputs.windows.parameters.dcrName.defaultValue = $DcrName + "-windows"
        $state.outputs.windows.parameters.dcrLocation.defaultValue = $state.runtime.dcrLocation
        $state.outputs.windows.resources[0].properties.description = "Azure monitor migration script generated windows rule"
        $state.outputs.windows.resources[0].properties.dataSources["performanceCounters"] = @()

        $dcrPerfCounterStream = "Microsoft-Perf"
        $dcrWindowsPerfCountersTable = [ordered]@{}
        $count = 1
        foreach($dataSource in $windowsPerfCounters)
        {
            $properties = $dataSource.Properties
            $currentKey = [string]$properties.intervalSeconds

            if($dcrWindowsPerfCountersTable.Contains($currentKey))
            {
                $counterSpecifierValidated = Get-ValidatedWindowsCounterSpecifier -counterSpecifier "\$($properties.objectName)($($properties.instanceName))\$($properties.counterName)"
                $dcrWindowsPerfCountersTable[$currentKey].counterSpecifiers += $counterSpecifierValidated
            }
            else
            {
                $counterSpecifierValidated = Get-ValidatedWindowsCounterSpecifier -counterSpecifier "\$($properties.objectName)($($properties.instanceName))\$($properties.counterName)"
                $newPerfCounter = New-Object DCRPerfCounterDataSource
                $newPerfCounter.name = "DS_$("WindowsPerformanceCounter")_$($count)"
                $newPerfCounter.counterSpecifiers = $counterSpecifierValidated
                $newPerfCounter.samplingFrequencyInSeconds = $properties.intervalSeconds
                $newPerfCounter.streams = $dcrPerfCounterStream
                $dcrWindowsPerfCountersTable.Add($currentKey, $newPerfCounter)
                $count += 1
            }
        }

        foreach($key in $dcrWindowsPerfCountersTable.Keys)
        {
            $state.outputs.windows.resources[0].properties.dataSources.performanceCounters += $dcrWindowsPerfCountersTable[$key]
        }

        $state.outputs.windows.resources[0].properties.dataFlows[0].streams += "Microsoft-Perf"
    }
}

<#
.DESCRIPTION
    Checks and parses Windows Event Logs
#>
function Get-WindowsEventLogs
{
    function Get-XPathQueryKey
    {
        param (
            [Parameter(Mandatory=$true)][Microsoft.Azure.Commands.OperationalInsights.Models.PSWindowsEventDataSourceProperties] $WindowsEventProperties
        )

        # AMA defines five log levels 
        # Critical (1), Error (2), Warning(3), Information(4) Verbose(5) and Undefined/Anything else (0)
        # whereas MMA seems to only have three
        # Error (2), Warning(3) and Information(4) 
        # but if set to collect Error event at MMA, both Error and Critical will be collected as Errro event.

        $eventTypeStr = ""

        foreach($type in $WindowsEventProperties.eventTypes)
        {   
            if($eventTypeStr.Length -gt 0)
            {
                $eventTypeStr += " or "
            }

            if($type.eventType.ToString() -eq "Error")
            {
                $eventTypeStr += "Level=1 or Level=2"
            }
            elseif($type.eventType.ToString() -eq "Warning")
            {
                $eventTypeStr += "Level=3"
            }
            elseif($type.eventType.ToString() -eq "Information")
            {
                $eventTypeStr += "Level=4 or Level=0"
            }
        }

        #Example: [System[(Level=1 or Level=2 or Level=3)]]
        return "[System[($($eventTypeStr))]]"
    }
    
    $windowsEventLogs = Get-AzOperationalInsightsDataSource -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Kind "WindowsEvent"
    if ($null -eq $windowsEventLogs)
    {
        Write-Host "Info: Windows Event Logs is not enabled on the workspace" -ForegroundColor Yellow
    }
    else {
        Write-Host "Info: Windows Event Logs is enabled on the workspace" -ForegroundColor Green
        $state.runtime.dataSourcesCount += 1
        $state.runtime.dcrTypesEnabled.windows = $true

        # Windows DCR output updates
        $state.outputs.windows.parameters.dcrName.defaultValue = $DcrName + "-windows"
        $state.outputs.windows.parameters.dcrLocation.defaultValue = $state.runtime.dcrLocation
        $state.outputs.windows.resources[0].properties.description = "Azure monitor migration script generated windows rule"
        $state.outputs.windows.resources[0].properties.dataSources["windowsEventLogs"] = @()

        # Compressing all the workspace events into a single dcr event log
        $dcrWindowsEvent = New-Object DCRWindowsEventLogDataSource
        $dcrWindowsEvent.name = "DS_WindowsEventLogs"
        $dcrWindowsEvent.streams = @("Microsoft-Event")
        $dcrWindowsEvent.xPathQueries = @()

        $iter_count = 0
        foreach($windowsEvent in $windowsEventLogs)
        {
            $xPathQuery = Get-XPathQueryKey -WindowsEventProperties $windowsEvent.Properties
            $dcrWindowsEvent.xPathQueries += "$($windowsEvent.Properties.eventLogName)!*$($xpathQuery)"
            $iter_count += 1
        }

        if ($iter_count -ne 0)
        {
            $state.outputs.windows.resources[0].properties.dataSources.windowsEventLogs += $dcrWindowsEvent
        }
        
        $state.outputs.windows.resources[0].properties.dataFlows[0].streams += "Microsoft-Event"
    }
}

<#
.DESCRIPTION
    Checks and parses the Linux Perf Counters on the workspace
#>
function Get-LinuxPerfCountersDataSource
{
    $linuxPerfCounters = Get-AzOperationalInsightsDataSource -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Kind "LinuxPerformanceObject"
    if ($null -eq $linuxPerfCounters)
    {
        Write-Host "Info: Linux Performance Counters is not enabled on the workspace" -ForegroundColor Yellow
    }
    else {
        Write-Host "Info: Linux Performance Counters is enabled on the workspace" -ForegroundColor Green
        $state.runtime.dataSourcesCount += 1
        $state.runtime.dcrTypesEnabled.linux = $true

        # Linux DCR output updates
        $state.outputs.linux.parameters.dcrName.defaultValue = $DcrName + "-linux"
        $state.outputs.linux.parameters.dcrLocation.defaultValue = $state.runtime.dcrLocation
        $state.outputs.linux.resources[0].properties.description = "Azure monitor migration script generated linux rule"
        $state.outputs.linux.resources[0].properties.dataSources["performanceCounters"] = @()

        $dcrLinuxPerfCountersTable = [ordered]@{}
        $count = 1
        foreach($dataSource in $linuxPerfCounters)
        {
            $properties = $dataSource.Properties
            $currentKey = "$($properties.objectName)-$($properties.intervalSeconds)"
            $newPerfCounter = New-Object DCRPerfCounterDataSource
            $newPerfCounter.name = "DS_$("LinuxPerformanceCounter")_$($count)"
            $newPerfCounter.counterSpecifiers = @()
            $newPerfCounter.samplingFrequencyInSeconds = $properties.intervalSeconds
            $newPerfCounter.streams = @("Microsoft-Perf")
            
            foreach($counter in $properties.performanceCounters)
            {
                $newPerfCounter.counterSpecifiers += "\$($properties.objectName)($($properties.instanceName))\$($counter.counterName)"
            }

            $dcrLinuxPerfCountersTable.Add($currentKey, $newPerfCounter)
            $count += 1
        }

        foreach($key in $dcrLinuxPerfCountersTable.Keys)
        {
            $state.outputs.linux.resources[0].properties.dataSources.performanceCounters += $dcrLinuxPerfCountersTable[$key]
        }

        $state.outputs.linux.resources[0].properties.dataFlows[0].streams += "Microsoft-Perf"
    }
}

<#
.DESCRIPTION
    Checks and parses Linux SysLogs
#>
function Get-LinuxSysLogs
{

    #####################################################
    function Get-SyslogLevels
    {
        param (
            [Parameter(Mandatory=$true)][Microsoft.Azure.Commands.OperationalInsights.Models.PSLinuxSyslogDataSourceProperties] $LinuxSyslogProperties
        )

        # Sorting the severities 
        # Sometimes the severities from the workpsace may not be in the correct order which is:
        # Emergency, Alert, Critical, Error, Warning, Notice, Info, Debug

        $sortedSeverities = New-Object string[] 8
        foreach($sev in $LinuxSyslogProperties.SyslogSeverities)
        {
            switch ($sev.Severity.value__) {
                0 { $sortedSeverities[0] = "Emergency"; Break }
                1 { $sortedSeverities[1] = "Alert"; Break }
                2 { $sortedSeverities[2] = "Critical"; Break }
                3 { $sortedSeverities[3] = "Error"; Break }
                4 { $sortedSeverities[4] = "Warning"; Break }
                5 { $sortedSeverities[5] = "Notice"; Break }
                6 { $sortedSeverities[6] = "Info"; Break }
                7 { $sortedSeverities[7] = "Debug" }
            }
        }

        # Remove the null entries
        $sortedSeverities = $sortedSeverities | Where-Object { $_ -ne $null }

        $syslogLevels = @()
        foreach($severity in $sortedSeverities)
        {
            switch($severity)
            {
                Emergency { $syslogLevels += "Emergency"; Break }
                Alert { $syslogLevels += "Alert"; Break }
                Critical { $syslogLevels += "Critical"; Break }
                Error { $syslogLevels += "Error"; Break }
                Warning { $syslogLevels += "Warning"; Break }
                Notice { $syslogLevels += "Notice"; Break }
                Info { $syslogLevels += "Info"; Break }
                Debug { $syslogLevels += "Debug" }
            }
        }

        [array]::Reverse($syslogLevels)
        return $syslogLevels
    }

    function Get-SyslogFacilityName
    {
        param (
            [Parameter(Mandatory=$true)][string] $MmaFacilityName
        )

        $amaFacilityName = ""
    
        switch($MmaFacilityName)
        {
            "auth"     { $amaFacilityName = "auth"; Break }
            "authpriv" { $amaFacilityName = "authpriv"; Break }
            "cron"     { $amaFacilityName = "cron"; Break }
            "daemon"   { $amaFacilityName = "daemon"; Break }
            "ftp"      { $amaFacilityName = "ftp"; Break }
            "kern"     { $amaFacilityName = "kern"; Break }
            "local0"   { $amaFacilityName = "local0"; Break }
            "local1"   { $amaFacilityName = "local1"; Break }
            "local2"   { $amaFacilityName = "local2"; Break }
            "local3"   { $amaFacilityName = "local3"; Break }
            "local4"   { $amaFacilityName = "local4"; Break }
            "local5"   { $amaFacilityName = "local5"; Break }
            "local6"   { $amaFacilityName = "local6"; Break }
            "local7"   { $amaFacilityName = "local7"; Break }
            "lpr"      { $amaFacilityName = "lpr"; Break  }
            "mail"     { $amaFacilityName = "mail"; Break }
            "news"     { $amaFacilityName = "news"; Break }
            "syslog"   { $amaFacilityName = "syslog"; Break }
            "user"     { $amaFacilityName = "user"; Break }
            "uucp"     { $amaFacilityName = "uucp"; Break }
            default    { $amaFacilityName = "*"; Break } # Is this safe to assume wildcad whenever there is no match?
        }

        return $amaFacilityName
    }
    #####################################################

    $linuxSyslogs = Get-AzOperationalInsightsDataSource -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Kind "LinuxSyslog"

    if($null -eq $linuxSysLogs)
    {
        Write-Host "Info: Linux SysLogs is not enabled on the workspace" -ForegroundColor Yellow
    }
    else {
        Write-Host "Info: Linux SysLogs is enabled on the workspace" -ForegroundColor Green
        $state.runtime.dataSourcesCount += 1
        $state.runtime.dcrTypesEnabled.linux = $true

        # Linux DCR output updates
        $state.outputs.linux.parameters.dcrName.defaultValue = $DcrName + "-linux"
        $state.outputs.linux.parameters.dcrLocation.defaultValue = $state.runtime.dcrLocation
        $state.outputs.linux.resources[0].properties.description = "Azure monitor migration script generated linux rule"
        $state.outputs.linux.resources[0].properties.dataSources["syslog"] = @()

        $dcrLinuxSyslogsTable = @{}
        $count = 1
        foreach($dataSource in $linuxSyslogs)
        {
            $properties = $dataSource.Properties
            if($properties.syslogSeverities.Length -gt 0)
            {
                $syslogLevels = Get-SyslogLevels -LinuxSyslogProperties $properties
                $logLevelsKey = $syslogLevels -join "-"
                if($dcrLinuxSyslogsTable.Contains($logLevelsKey))
                {
                    $dcrLinuxSyslogsTable[$logLevelsKey].facilityNames += Get-SyslogFacilityName  -mmaFacilityName $properties.syslogName
                }
                else
                {
                    $newLinuxSyslog = New-Object DCRSyslogDataSource
                    $newLinuxSyslog.name = "DS_$("LinuxSyslog")_$($count)"
                    $facilityName = Get-SyslogFacilityName -mmaFacilityName $properties.syslogName
                    $newLinuxSyslog.facilityNames = @($facilityName)
                    $newLinuxSyslog.logLevels = $syslogLevels
                    $newLinuxSyslog.streams = @("Microsoft-Syslog")
                    $dcrLinuxSyslogsTable.Add($logLevelsKey, $newLinuxSyslog)
                    $count += 1
                }
            }
        }

        foreach($key in $dcrLinuxSyslogsTable.Keys)
        {
            $state.outputs.linux.resources[0].properties.dataSources.sysLog += $dcrLinuxSyslogsTable[$key]
        }

        $state.outputs.linux.resources[0].properties.dataFlows[0].streams += "Microsoft-Syslog"
    }
} 

<#
.DESCRIPTION
    Fetches and parses any extension data sources present on the workspace
#>
function Get-ExtensionDataSources
{
    $workspaceExtensions = Get-AzOperationalInsightsIntelligencePack -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName

    # Case 1: VM Insights
    $vmInsights = $workspaceExtensions | Where-Object {$_.name -match ".*VMInsights*" }

    if ($null -ne $vmInsights -and $vmInsights.enabled -eq $True)
    {
        Write-Host 'Info: VM Insights Extension Data Source is enabled on the workspace' -ForegroundColor Green
        $state.runtime.dataSourcesCount += 1
        $state.runtime.dcrTypesEnabled.extensions = $true

        # Extensions DCR output updates
        $state.outputs.windows.parameters.dcrName.defaultValue = $DcrName + "-extensions"
        $state.outputs.extensions.parameters.dcrLocation.defaultValue = $state.runtime.dcrLocation
        $state.outputs.extensions.resources[0].properties.description = "Azure monitor migration script generated extensions rule"
        $state.outputs.extensions.resources[0].properties.dataSources["performanceCounters"] = @()
        $state.outputs.extensions.resources[0].properties.dataSources["extensions"] = @()

        # VM Insights Perf counter
        $vmInsightsPerfCounter = [ordered]@{
            "name" = "VMInsightsPerfCounters"
            "streams" = @("Microsoft-InsightsMetrics")
            "samplingFrequencyInSeconds" = 60
            "counterSpecifiers" = @("\VmInsights\DetailedMetrics")
        }

        $state.outputs.extensions.resources[0].properties.dataSources.performanceCounters += $vmInsightsPerfCounter
        $state.outputs.extensions.resources[0].properties.dataFlows[0].streams += "Microsoft-InsightsMetrics"

        # VM Insights Extension
        $vmInsightsExtension = [ordered]@{
            "streams" = @("Microsoft-ServiceMap")
            "extensionName" = "DependencyAgent"
            "extensionSettings" = @{}
            "name" = "DependencyAgentDataSource"
        }

        Write-Host 'Info: Added Microsoft-InsightsMetrics and Microsoft-ServiceMap streams as part of the VM Insights Extension' -ForegroundColor Yellow

        $state.outputs.extensions.resources[0].properties.dataSources.extensions += $vmInsightsExtension
        $state.outputs.extensions.resources[0].properties.dataFlows[0].streams += "Microsoft-ServiceMap"
    }
    else {
        Write-Host 'Info: VM Insights Extension Data Source is not enabled on the workspace' -ForegroundColor Yellow
    }
}

<#
.DESCRIPTION
    Makes an ARM call to create a DCE
#>
function Get-ProvisionDCE
{
    Write-Host "Info: Provisioning a Data Collection Endpoint (DCE) on your behalf" -ForegroundColor Cyan
    $dceSubId = Read-Host ">>>>> Sub Id"
    $dceRg = Read-Host ">>>>> Resource Group"
    $dceName = Read-Host ">>>>> Name"
    Write-Host ">>>>> Location: $($state.runtime.dcrLocation)"
    $accessToken = Get-AzAccessToken
    $accessToken | Out-Null # Shouldn't print this out to the console

    $apiUrl = "https://management.azure.com/subscriptions/$($dceSubId)/resourceGroups/$($dceRg)/providers/Microsoft.Insights/dataCollectionEndpoints/$($dceName)?api-version=2022-06-01"
    $headers = @{
        'Authorization' = "Bearer $($accessToken.Token)"
    }

    $body = @{
        "location" = $state.runtime.dcrLocation
        "properties" = @{
            "description" = "A data Collection Endpoint"
        }
    }
    $bodyData = $body | ConvertTo-Json

    try {
        # Replace this AMCS PS CMDLET when it's ready
        $response = Invoke-RestMethod -Uri $apiUrl -Method PUT -Headers $headers -Body $bodyData -ContentType "application/json"
        $response | Out-Null 
    }
    catch {
        Write-Host "Error in provisioning the DCE: $PSItem" -ForegroundColor Red
        Write-Host
        Exit
    }

    $dceArmId = $response.id
    Write-Host "Info: The DCE was successfully provisioned: $($dceArmId)" -ForegroundColor Green

    return $dceArmId
}

<#
.DESCRIPTION
    Makes sure a Data Collection Endpoint Id is present in the payload whenever necessary
#>
function Set-FulfillDCERequirement
{
    if ($null -ne $state.runtime.dce)
    {
        Write-Host "Info: DCE requirement already fulfilled" -ForegroundColor Green
    }
    else{
        $provisionDCE = Read-Host "Do you want us to provision a DCE for you (in case you don't have one)? (y/n)"
        $provisionDCE = $provisionDCE.Trim().ToLower()

        $dceArmId = "/subscriptions/{subId}/resourceGroups/{resourceGroup}/providers/Microsoft.Insights/dataCollectionEndpoints/{dceName}"

        if ("y" -eq $provisionDCE)
        {
            $dceArmId = Get-ProvisionDCE
        }
        else{
            $cxDce = Read-Host "Please provide the full ARM ID of the DCE to use"
            $cxDce = $cxDce.Trim().ToLower()

            if ($null -eq $cxDce -or "" -eq $cxDce)
            {
                Write-Host "Info: You will need to provide a valid Data Collection Endpoint Id in the parameters section of the DCR" -ForegroundColor DarkYellow
                Write-Host
            }
            else {
                $dceArmId = $cxDce
                Write-Host "Info: The following DCE will be used in the data collection rule: $($dceArmId)" -ForegroundColor Cyan
            }
        }
        
        $state.runtime["dce"] = [ordered]@{
            "type" = "string"
            "defaultValue" = $dceArmId
            "metadata" = [ordered]@{
                "description" = "The ARM Id of the Data Collection Endpoint being associated to this DCR"
            }
        }
    }
}

<#
.DESCRIPTION
    Refer to this article https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-custom-text-log-migration
    This function migrates a MMA Custom text log table so it can be used as a destination for a new AMA custom text logs DCR.
    This is only for customers who want to preserve data
#>
function Set-MigrateMMABasedCustomTable
{
    param(
        [Parameter(Mandatory=$True)]
        [string]$tableName
    )

    $accessToken = Get-AzAccessToken
    $accessToken | Out-Null # Shouldn't print this out to the console

    $apiUrl = "https://management.azure.com/$($state.runtime.workspace.ResourceId)/tables/$($tableName)/migrate?api-version=2021-12-01-preview"
    $headers = @{
        'Authorization' = "Bearer $($accessToken.Token)"
    }

    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers
    $response | Out-Null

    Write-Host "Info: The table $($tableName) has been successfully migrated. Both AMA and MMA will be able to ingest custom logs into it." -ForegroundColor Green
}

<#
.DESCRIPTION
    Checks and parses Custom Logs
#>
function Get-CustomLogs
{
    <#
    .DESCRIPTION
        Extracts the file patterns for a given custom table
    #>
    function Get-FilePatterns
    {
        param(
            [Parameter(Mandatory=$true)][System.Object] $customLog
        )

        $filePatterns = @()

        foreach ($input in $customLog.Properties.Inputs)
        {
            if($null -ne $input.location.fileSystemLocations.linuxFileTypeLogPaths)
            {
                foreach ($linuxPath in $input.location.fileSystemLocations.linuxFileTypeLogPaths)
                {
                    $filePatterns += $linuxPath
                }
            }

            if($null -ne $input.location.fileSystemLocations.windowsFileTypeLogPaths)
            {
                foreach ($windowsPath in $input.location.fileSystemLocations.windowsFileTypeLogPaths)
                {
                    $windowsPathCorrected = $windowsPath.Replace("\\", "\")
                    $filePatterns += $windowsPathCorrected
                }    
            }
        }

        return $filePatterns 
    }

    # This returns MMA based custom tables or MMA based custom tables that have been migrated to Manual Schema Management
    # For MMA based custom tables that haven't been migrated yet, the customer needs to perform the migration for the custom logs ingestion via AMA to work
    # Another alternative will be to create a new custom table. Refer to this article https://learn.microsoft.com/en-us/azure/azure-monitor/agents/data-collection-text-log?tabs=portal
    $customLogs = Get-AzOperationalInsightsDataSource -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -Kind "CustomLog"

    if ($null -eq $customLogs)
    {
        Write-Host "Info: Custom Logs is not enabled on the workspace" -ForegroundColor Yellow
    }
    else {
        Write-Host "Info: Custom Logs is enabled on the workspace" -ForegroundColor Green
        Write-Host
        $state.runtime.dataSourcesCount += 1
        $state.runtime.dcrTypesEnabled.cls = $true

        Write-Host "Info: We will migrate each MMA based custom classic table that hasn't yet been migrated" -ForegroundColor Cyan
        Write-Host "Info: Learn more about migrating MMA based custom tables here >> https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-custom-text-log-migration" -ForegroundColor Cyan

        Write-Host "Info: In case you don't want to preserve data and create new AMA/DCR based custom tables, you will have to manually update the arm templates with the new table names" -ForegroundColor Cyan
        Write-Host "Info: Learn more about AMA Custom Logs here >> https://learn.microsoft.com/en-us/azure/azure-monitor/agents/data-collection-text-log?tabs=portal" -ForegroundColor Cyan

        ########################################################
        # DCE required for custom logs
        Write-Host
        Write-Host "Info: A Data Collection Endpoint is required for the Ingestion of Custom Logs via DCR" -ForegroundColor Cyan
        Set-FulfillDCERequirement

        $iter_count = 1

        foreach($customLog in $customLogs)
        {
            $clArmTemplate = Get-BaseArmTemplate
            $clArmTemplate.parameters.dcrName.defaultValue = "$($customLog.Properties.customLogName)_dcr"
            $clArmTemplate.parameters.dcrName.defaultValue = $clArmTemplate.parameters.dcrName.defaultValue.ToLower()
            $clArmTemplate.parameters.dcrLocation.defaultValue = $state.runtime.dcrLocation
            $clArmTemplate.parameters.dceArmId = $state.runtime.dce

            $clArmTemplate.resources[0].properties.description = "Azure monitor migration script generated custom logs rule"
            $clArmTemplate.resources[0].properties["dataCollectionEndpointId"] = "[parameters('dceArmId')]"

            $customStreamName = "Custom-Input-$($customLog.Properties.customLogName)"
            $outputStreamName = "Custom-$($customLog.Properties.customLogName)"
            $clArmTemplate.resources[0].properties["streamDeclarations"] = @{ 
                $customStreamName = [ordered]@{ #Usinfg the default schema - Cx should update this to fit their use case
                    "columns" = @(
                        @{
                            "name" = "TimeGenerated";
                            "type" = "datetime";
                        },
                        @{
                            "name" = "RawData";
                            "type" = "string";
                        }
                    )
                }
            }

            $fPatterns = @(Get-FilePatterns -customLog $customLog)
            $customLogDataSource = [ordered]@{
                "name" = "customLogFile_DS_$($iter_count)"
                "streams" = @($customStreamName)
                "filePatterns" = $fPatterns
                "format" = "text"
                "settings" = [ordered]@{
                    "text" = [ordered]@{
                        "recordStartTimestampFormat" = "ISO 8601"
                    }
                }
            }

            $clArmTemplate.resources[0].properties.dataSources["logFiles"] = @($customLogDataSource)
            $clArmTemplate.resources[0].properties.dataFlows[0].streams += ($customStreamName)
            $clArmTemplate.resources[0].properties.dataFlows[0]["outputStream"] = $outputStreamName
            $clArmTemplate.resources[0].properties.dataFlows[0]["kqlTransform"] = "source"

            ######################################################################
            # Automatically migrate the MMA based custom table
            # TO DO: if this fails, don't add this custom log definition to the output DCR
            Set-MigrateMMABasedCustomTable -tableName $customLog.Properties.customLogName

            $iter_count += 1

            $state.outputs.cls += $clArmTemplate
        }
    }
}

<#
.DESCRIPTION
    Cheks whether or not IIS Logs Collection is enabled on the workspace
#>
function Get-IsIISLogsDataSourceEnabled
{
    param(
        [Parameter(Mandatory=$true)][System.Object] $workspace
    )
    $accessToken = Get-AzAccessToken
    $accessToken | Out-Null # Shouldn't print this out to the console

    $apiUrl = "https://management.azure.com$($workspace.ResourceId)/dataSources?%24filter=kind%20eq%20'IISLogs'&api-version=2020-08-01"
    $headers = @{
        'Authorization' = "Bearer $($accessToken.Token)"
    }

    $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers
    $response | Out-Null

    # response.value is an array
    # We return false when response.value is empty or response.value[0].properties.state = "OnPremiseDisabled"
    # We return True other
    if ($response.value.Count -ne 0 -and $response.value[0].properties.state -eq "OnPremiseEnabled")
    {
        Write-Host "Info: IIS Logs is enabled on the workspace" -ForegroundColor Green
        return $True
    }
    else {
        Write-Host "Info: IIS Logs is not enabled on the workspace" -ForegroundColor Yellow
        return $False
    }
}

<#
.DESCRIPTION
    Checks and parses IIS Logs
#>
function Get-IISLogs 
{
    $isIISLogsEnabled = Get-IsIISLogsDataSourceEnabled -workspace $state.runtime.workspace
    if ($True -eq $isIISLogsEnabled)
    {
        $state.runtime.dataSourcesCount += 1
        $state.runtime.dcrTypesEnabled.iis = $true

        # DCE required for iis logs
        Write-Host "Info: A Data Collection Endpoint is required for the Ingestion of IIS Logs via DCR" -ForegroundColor Cyan
        Set-FulfillDCERequirement

        $iisLogsDataSource = @([ordered]@{
                "name" = "myiislogsdatasource"
                "streams" = @("Microsoft-W3CIISLog")
                "logDirectorties" = @() #double check what to pass here. DCR contract has it.
        })

        $state.outputs.iis.parameters.dcrName.defaultValue = $DcrName + "-iis"
        $state.outputs.iis.parameters.dcrLocation.defaultValue = $state.runtime.dcrLocation
        $state.outputs.iis.parameters["dceArmId"] = $state.runtime.dce
        $state.outputs.iis.resources[0].properties.description = "Azure monitor migration script generated iis logs rule"
        $state.outputs.iis.resources[0].properties["dataCollectionEndpointId"] = "[parameters('dceArmId')]"
        $state.outputs.iis.resources[0].properties.dataSources["iisLogs"] = $iisLogsDataSource
        $state.outputs.iis.resources[0].properties.dataFlows[0].streams += "Microsoft-W3CIISLog"
    }
}

<#
.DESCRIPTION
    Fetches and parses all the supported data sources
#>
function Get-UserLogAnalyticsWorkspaceDataSources
{
    # Query the workspaces data sources
    # All the data source types
    # 1. Windows Perf Counters: WindowsPerformanceCounter
    # 2. Linux Perf Counters: LinuxPerformanceObject
    # 3. Windows Event Logs: WindowsEvent
    # 4. Syslogs: LinuxSyslog
    # 5. Custom Logs: CustomLog
    # 6. IIS logs: IISLogs (This check is done via HTTP Rest)
    Write-Host
    Write-Host 'Info: Fetching the Log Analytics Workspace data sources' -ForegroundColor Cyan
    Write-Host

    # Windows Performance Counters
    Get-WindowsPerfCountersDataSource
    Write-Host

    # Linux Performance Counters
    Get-LinuxPerfCountersDataSource
    Write-Host

    # Windows Event Logs
    Get-WindowsEventLogs
    Write-Host

    # Linux Syslogs
    Get-LinuxSysLogs
    Write-Host

    # Extensions Data Sources
    Get-ExtensionDataSources 
    Write-Host

    # Custom Logs
    Get-CustomLogs
    Write-Host

    # IIS Logs
    Get-IISLogs
    Write-Host
}

<#
.DESCRIPTION
    Utility function to handle single quote characters in the json string
#>
function ConvertTo-ReplaceSepcialChars
{
    process {
        $_ -replace '\\u0027', "'"
    }
}

<#
.DESCRIPTION
    Generates all the output files
#>
function Get-Output
{
    Write-Host
    if ($state.runtime.dataSourcesCount -eq 0)
    {
        Write-Host 'Info: No supported data sources were found on the workspace.' -ForegroundColor DarkYellow
        Write-Host 'Info: No output file(s) will be generated.' -ForegroundColor DarkYellow
        Write-Host
        Exit
    }
    else{
        $correctedOutputFolder = $state.runtime.outputFolder

        $dcrTypes = @("windows", "linux", "extensions", "cls", "iis")
        foreach ($type in $dcrTypes)
        {
            if ($state.runtime.dcrTypesEnabled[$type] -eq $true)
            {
                if ("cls" -eq $type) #Special handling for custom logs DCRs
                {
                    $counter = 0
                    foreach ($cl in $state.outputs.cls)
                    {
                        $fileName = $cl.parameters.dcrName.defaultValue

                        Write-Host "Info: Generating the $type rule arm template file $counter ($($fileName)_arm_template.json)" -ForegroundColor Cyan
                        $cl | ConvertTo-Json -Depth 100 | ConvertTo-ReplaceSepcialChars | Out-File -FilePath "$correctedOutputFolder\$($fileName)_arm_template.json"
        
                        Write-Host "Info: Generating the $type rule payload file $counter ($($fileName)_payload.json)" -ForegroundColor Cyan
                        $cl["resources"][0].properties | ConvertTo-Json -Depth 100 | ConvertTo-ReplaceSepcialChars | Out-File -FilePath "$correctedOutputFolder\$($fileName)_payload.json"

                        $counter += 1
                    }
                }
                else {
                    Write-Host "Info: Generating the $type rule arm template file ($($type)_dcr_arm_template.json)" -ForegroundColor Cyan
                    $state.outputs[$type] | ConvertTo-Json -Depth 100 | ConvertTo-ReplaceSepcialChars | Out-File -FilePath "$correctedOutputFolder\$($type)_dcr_arm_template.json"
    
                    Write-Host "Info: Generating the $type rule payload file ($($type)_dcr_payload.json)" -ForegroundColor Cyan
                    $state.outputs[$type]["resources"][0].properties | ConvertTo-Json -Depth 100 | ConvertTo-ReplaceSepcialChars | Out-File -FilePath "$correctedOutputFolder\$($type)_dcr_payload.json"

                }
            }
        }

        Write-Host "Info: Done. Check your output folder ($($correctedOutputFolder)) for all the generated files!" -ForegroundColor Green
        Write-Host
    }
}

<#
.DESCRIPTION
    Runs test deployments of the generated arm templates
#>
function Set-DeployOutputOnAzure
{
    $deployGeneratedArmTemplate = Read-Host "Do you want to run a test deployment of one of the generated DCR ARM templates? (y/n)"
    $deployGeneratedArmTemplate = $deployGeneratedArmTemplate.Trim().ToLower()
    Write-Host

    while ("y" -eq $deployGeneratedArmTemplate)
    {
        $azConetxt = Get-AzContext
        Write-Host ">>>> Deployment Subscription:   $($azConetxt.Subscription.Id)"
        $resourceGroupName = Read-Host ">>>> Deployment Resource Group"
        $armTemplateFile = Read-Host ">>>> ARM template file name   "
        try 
        {
            New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "$($state.runtime.outputFolder)\$armTemplateFile" -ErrorAction Stop
            Write-Host "Info: Deployment done! Check your resource group in Azure for the newly created DCR." -ForegroundColor Green
            Write-Host
        } catch {
            Write-Host "Error while deploying: $PSItem" -ForegroundColor Red
        }

        $deployGeneratedArmTemplate = Read-Host "Do you want to run another deployment? (y/n)"
        $deployGeneratedArmTemplate = $deployGeneratedArmTemplate.Trim().ToLower()
    }
}

#endregion

#region Logic
$global:state = [ordered]@{
    "runtime" = [ordered]@{
        "dcrTypesEnabled" = [ordered]@{ # Used for final output
            "windows" = $false
            "linux" = $false
            "extensions" = $false
            "cls" = $false
            "iis" = $false 
        }
        "dataSourcesCount" = 0
    }
}
###########################################################
Set-ValidateOutputFolder

$WarningPreference = 'SilentlyContinue'
Set-AzSubscriptionContext -SubscriptionId $SubscriptionId
$WarningPreference = 'Continue'

Set-InitializeOutputs
Get-UserLogAnalyticsWorkspace 
Get-UserLogAnalyticsWorkspaceDataSources
Get-Output

Set-DeployOutputOnAzure
#endregion