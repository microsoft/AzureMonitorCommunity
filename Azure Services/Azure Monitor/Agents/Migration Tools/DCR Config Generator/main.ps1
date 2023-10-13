<#
File: 
Author: Azure Monitor Control Service
Email: amcsdev@microsoft.com
Description: This module contains code to help our customers migrate from MMA based configurations to AMA based configuration

License: MIT License

Copyright (c) 2023 Microsoft
#>

param(
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
    [switch]$GetDcrPayload,

    [Parameter(Mandatory=$False)]
    [string]$DCEName = "null"
)


function Get-DcrDefaultPayload
{
    $payload = @{
        "description" = "A Data Collection Rule"
        "dataCollectionEndpointId" = $null
        "streamDeclarations" = $null
        "dataSources" = $null
        "destinations" = $null
        "dataFlows" = $null
    }

    $filePath = "./output.json" # Meaning the current directory

    $payload | ConvertTo-Json | Out-File -FilePath $filePath
}

Get-DcrDefaultPayload

#region Utility Functions

function Set-AzContext {
    param (
        # This helps tie the AzContext to a specific Subscription 
        [Parameter(Mandatory=$true)][string] $SubscriptionId
    )

    $azContext = Get-AzContext

    if ($null -ne $azContext)
    {
        Write-Output "You are already logged into Azure"

        $currentAzContextSubId = $azContext.Subscription.Id

        if($currentAzContextSubId -ne $SubscriptionId)
        {
            Write-Output "Switching to a new context"
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

function Get-OutputFolder
{
    $FolderPath = $null

    if(-not ($PSBoundParameters.ContainsKey('FolderPath')))
    {
        $FolderPath = "."
    }

    if($FolderPath.LastIndexOf("/") -eq $FolderPath.Length-1)
    {
        $FolderPath = $FolderPath.Substring(0, $FolderPath.Length-1)
    }

    return $FolderPath
}

#endregion

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

class DCRExtensionDataSource
{
    [string]$name
    [string[]]$streams
    [string]$extensionName
    [System.Object]$extensionSettings
    [string[]]$inputDataSources
}

class DCRIISLogDataSource
{
    [string]$name
    [string[]]$streams
    [string[]]$logDirectories
}

class DCRLogFileDataSource
{
    [string]$name
    [string[]]$streams
    [string[]]$filePatterns
    [string]$format
    [DCRLogFileDataSourceLogFileSettings]$settings
}

class DCRLogFileDataSourceLogFileSettings
{
    [DCRLogFileDataSourceLogFileTextSettings]$text
}

class DCRLogFileDataSourceLogFileTextSettings
{
    [string]$recordStartTimestampFormat
}

# 2. Destinations
class DCRLogAnalyticsWorkspaceDestination
{
    [string]$name
    [string]$workspaceResourceId
    [string]$worskpaceId
}

# 3. Custom Logs
class DCRStreamDeclaration
{
    [ColumnDefinition[]]$columns
}

class ColumnDefinition
{
    [string]$name
    [string]$type
}

# 4. Data Flows
class DCRDataFlow
{
    [string[]]$streams
    [string[]]$destinations
    [string]$transformKql
    [string]$outputStream
    [string]$builtinTransform
}

# 5. Log Analytics Workspace
class LogAnalyticsWorkspace
{
    [string]$name
}
#endregion
