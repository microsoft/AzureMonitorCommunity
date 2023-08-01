function Find-IfVmiEnabled
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName
    )
    
    if ((Get-AzOperationalInsightsIntelligencePack -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName | Where-Object {$_.name -match ".*VMInsights*" }).Length -eq 0) {
        return $False
    }

    return $True
}

function Get-VmiDataSources
{
    param (
        [Parameter(Mandatory=$true)][bool] $ProcessAndDependencies
    )
    
    $vmiPerfCounter = [ordered]@{
        "name" = "VMInsightsPerfCounters";
        "streams" = @("Microsoft-InsightsMetrics");
        "scheduledTransferPeriod" = "PT1M";
        "samplingFrequencyInSeconds" = 60;
        "counterSpecifiers" = @("\\VmInsights\\DetailedMetrics");
    }
    $vmiPerfCounters = @($vmiPerfCounter)
    $vmiDataSources = [ordered]@{
        "performanceCounters" = $vmiPerfCounters;
    }
    if ($ProcessAndDependencies) {
        $vmiExtension = [ordered]@{
        "streams" = @("Microsoft-ServiceMap");
        "extensionName" = "DependencyAgent";
        "extensionSettings" = @{};
        "name" = "DependencyAgentDataSource";
        }
        $vmiDataSources["extensions"] = @($vmiExtension)
    }    
    return $vmiDataSources
}

function Get-VmiDestinations
{
    param (
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName
    )
    
    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName
    $laDest =
    [ordered]@{
        "workspaceResourceId" = $workspace.ResourceId;
        "name" = "VMInsightsPerf-Logs-Dest";
    }
    $vmiDestinations = 
    @{
        "logAnalytics" = @($laDest);
    }
    return $vmiDestinations
}

function Get-VmiDataFlows
{
    param (
        [Parameter(Mandatory=$true)][bool] $ProcessAndDependencies
    )

    $vmiDataFlows = [System.Collections.ArrayList]::new()
    $InsightDataFlow =
    [ordered]@{
        "streams" = @("Microsoft-InsightsMetrics");
        "destinations" = @("VMInsightsPerf-Logs-Dest");
    }
    $ServiceMapDataFlow =
    [ordered]@{
        "streams" = @("Microsoft-ServiceMap");
        "destinations" = @("VMInsightsPerf-Logs-Dest");
    }
    $vmiDataFlows.Add($InsightDataFlow) | Out-Null
    if ($ProcessAndDependencies) {
        $vmiDataFlows.Add($ServiceMapDataFlow) | Out-Null
    }
    return $vmiDataFlows
}

function Get-VmiDcrArmTemplate
{
  param (
        [Parameter(Mandatory=$true)][bool] $ProcessAndDependencies,
        [Parameter(Mandatory=$true)][string] $ResourceGroupName,
        [Parameter(Mandatory=$true)][string] $WorkspaceName,
        [Parameter(Mandatory=$true)][string] $Location,
        [Parameter(Mandatory=$True)][string] $DcrName
    )

    $vmiDataSources = Get-VmiDataSources -ProcessAndDependencies $ProcessAndDependencies
    $vmiDataDestinations = Get-VmiDestinations -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
    $vmiDataFlows = Get-VmiDataFlows -ProcessAndDependencies $ProcessAndDependencies
    $result = @{}
    if($vmiDataDestinations -eq $null) {
        return $null
    }
    #ARM Template File
    $schema = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    $contentVersion = "1.0.0.0"
    if ($ProcessAndDependencies) {
        $vmiDcrName = "MSVMI-PerfandDa-$DcrName-dcr"
    } else {
        $vmiDcrName = "MSVMI-Perf-$DcrName-dcr"
    }
    $parameters = @{}
    $variables = @{}
    $resources = @(
    [ordered]@{
        "type" = "Microsoft.Insights/dataCollectionRules";
        "apiVersion" = "2021-04-01";
        "name" = $vmiDcrName;
        "location" = $Location;
        "properties" = [ordered]@{
            "description" = "Data collection rule for VM Insights.";
            "dataSources" = $vmiDataSources;
            "destinations" = $vmiDataDestinations;
            "dataFlows" = @($vmiDataFlows);
         }
    }) 
    $vmiDcrTemplate =
    [ordered]@{
        "`$schema" = $schema;
        "contentVersion" = $contentVersion;
        "parameters" = $parameters;
        "variables" = $variables;
        "resources" = $resources
    }
    
    $result = ConvertTo-Json -InputObject $vmiDcrTemplate -Depth 100
    return $result
}

function Get-VmiDcrBaseArmTemplateParams
{
    param (
        [Parameter(Mandatory=$true)][string] $DcrName
    )
    #ARM Template Parameters File
    $schema = "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
    $contentVersion = "1.0.0.0"
    $paramName = "dataCollectionRules_name"
    $parameters = @{
        "$($paramName)" = $DcrName;
    }

    $dcrTemplateParams = 
    [ordered]@{
        "`$schema" = $schema;
        "contentVersion" = $contentVersion;
        "parameters" = $parameters
    }

    return ConvertTo-Json -InputObject $vmiDcrTemplate -Depth 100
}