Param(
    [Parameter(Mandatory = $True)]
    [string]$InputWorkspaceResourceId,

    [Parameter(Mandatory = $True)]
    [string]$OutputWorkspaceResourceId,

    [Parameter(Mandatory = $True)]
    [string]$OutputDCRName,

    [Parameter(Mandatory = $True)]
    [string]$OutputDCRLocation,

    [Parameter(Mandatory = $True)]
    [string]$OutputDCRTemplateFolderPath
)
#check if input workspaceID and output workspaceID are identical or not
if ($InputWorkspaceResourceId -eq $OutputWorkspaceResourceId) {
    Write-Host "The operation failed because the InputWorkspaceResourceId and the OutputWorkspaceResourceId are identical. Please specify a different OutputWorkspaceResourceId and try again. This is necessary to avoid overwriting the original data and to ensure data integrity." -ForegroundColor red
    throw "Terminating since above conditions were not met."
}
# token access function
function GetAccessToken {
    try {
        Connect-AzAccount -ErrorAction Stop
        $accessToken = (Get-AzAccessToken -ErrorAction Stop).Token
        return $accessToken
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor red
        exit
    }
  
}
#function to find pathtype(absolute or relative)
function TestPathType {
    param (
        [string]$Path
    )
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return "Absolute Path"
    }
    else {
        return "Relative Path"
    }
}
# 1 parse and migrate windows tracking services
function GetWindowsTrackingServices {
    $ctv1FileResponse = Invoke-RestMethod "https://management.azure.com$($InputWorkspaceResourceId)/datasources?`$filter=kind+eq+%27ChangeTrackingServices%27&api-version=2015-11-01-preview"-Method Get -Headers $headers -UseBasicParsing -ContentType "application/json"
    # check if collectionTimeInterval is greater than 600 or not. if not make it 600(10 minutes)
    $cvtv1CollectionTimeInterval = if ($ctv1FileResponse.value.properties.CollectionTimeInterval -gt 600) { $ctv1FileResponse.value.properties.CollectionTimeInterval } else { 600 }
    $ctv2JsonObject.resources[0].properties.dataSources.extensions[0].extensionSettings.servicesSettings.serviceCollectionFrequency = $cvtv1CollectionTimeInterval
}
# 2 parse and migrate windows file settings
function GetWindowsFileSetting {
    $ctv1FileResponse = Invoke-RestMethod "https://management.azure.com$($InputWorkspaceResourceId)/datasources?`$filter=kind+eq+%27ChangeTrackingCustomPath%27&api-version=2015-11-01-preview"-Method Get -Headers $headers -UseBasicParsing -ContentType "application/json"
    $fileSettingObjectList = New-Object System.Collections.ArrayList
    foreach ($object in $ctv1FileResponse.value) {
        foreach ($objectProperties in $object.Properties) {
            $ctv2SettingObject = [PSCustomObject]@{
                name                  = $object.name
                enabled               = if ($objectProperties.enabled -eq "true") { $true } else { $false }
                description           = ""
                path                  = $objectProperties.path
                recurse               = if ($objectProperties.recurse -eq "true") { $true } else { $false }
                maxContentsReturnable = if ($objectProperties.maxContentsReturnable -eq 0) { 5000000 } else { $objectProperties.maxContentsReturnable }
                maxOutputSize         = if ($objectProperties.maxOutputSize -eq 0) { 500000 } else { $objectProperties.maxOutputSize }
                checksum              = $objectProperties.checksum
                pathType              = $objectProperties.pathType
                groupTag              = $objectProperties.groupTag
            }
            $fileSettingObjectList.Add($ctv2SettingObject) > $null
        }
    }
    $ctv2JsonObject.resources[0].properties.dataSources.extensions[0].extensionSettings.fileSettings.fileinfo = $fileSettingObjectList
}
# 3 parse and migrate windows registory settings
function GetWindowsRegistorySettings {
    $ctv1RegistryResponse = Invoke-RestMethod "https://management.azure.com$($InputWorkspaceResourceId)/datasources?`$filter=kind+eq+%27ChangeTrackingDefaultRegistry%27&api-version=2015-11-01-preview"-Method Get -Headers $headers -UseBasicParsing -ContentType "application/json"
    $registrySettingsObjectList = New-Object System.Collections.ArrayList
    foreach ($object in $ctv1RegistryResponse.value) {
        foreach ($objectProperties in $object.Properties) {
            $ctv2SettingObject = [PSCustomObject]@{
                name        = $object.name
                groupTag    = if ($objectProperties.groupTag -eq "") { "Recommended" }else { $objectProperties.groupTag }
                enabled     = if ($objectProperties.enabled -eq "true") { $true }else { $false }
                recurse     = if ($objectProperties.recurse -eq "true") { $true } else { $false }
                description = ""
                keyName     = $objectProperties.keyName
                valueName   = $objectProperties.valueName
            }
            $registrySettingsObjectList.Add($ctv2SettingObject) > $null
        }
    }
    $ctv2JsonObject.resources[0].properties.dataSources.extensions[0].extensionSettings.registrySettingsObjectList.registryInfo = $registrySettingsObjectList
}
# 4 parse and migrate linux file settings
function GetLinuxFileSettings {
    $ctv1LinuxFileResponse = Invoke-RestMethod "https://management.azure.com$($InputWorkspaceResourceId)/datasources?`$filter=kind+eq+%27ChangeTrackingLinuxPath%27&api-version=2015-11-01-preview"-Method Get -Headers $headers -UseBasicParsing -ContentType "application/json"
    $fileSettingObjectList = New-Object System.Collections.ArrayList
    foreach ($object in $ctv1LinuxFileResponse.value) {
        foreach ($objectProperties in $object.Properties) {
            $ctv2SettingObject = [PSCustomObject]@{
                name                  = $object.name
                enabled               = if ($objectProperties.enabled -eq "true") { $true } else { $false }
                destinationPath       = $objectProperties.destinationPath
                useSudo               = if ($objectProperties.useSudo -eq "true") { $true } else { $false }
                recurse               = if ($objectProperties.recurse -eq "true") { $true } else { $false }
                maxContentsReturnable = if ($objectProperties.maxContentsReturnable -eq 0) { 5000000 } else { $objectProperties.maxContentsReturnable }
                pathType              = $objectProperties.pathType
                type                  = $objectProperties.type
                links                 = $objectProperties.links
                maxOutputSize         = if ($objectProperties.maxOutputSize -eq 0) { 5 } else { $objectProperties.maxOutputSize }
                groupTag              = $objectProperties.groupTag
            }
            $fileSettingObjectList.Add($ctv2SettingObject) > $null
        }
    }
    $ctv2JsonObject.resources[0].properties.dataSources.extensions[1].extensionSettings.fileSettings.fileinfo = $fileSettingObjectList
}
# 5 parse and migrate global settings
function GetDataTypeConfiguration {
    $ctv1DatatypeConfigurationResponse = Invoke-RestMethod "https://management.azure.com$($InputWorkspaceResourceId)/datasources?`$filter=kind+eq+%27ChangeTrackingDataTypeConfiguration%27&api-version=2015-11-01-preview"-Method Get -Headers $headers -UseBasicParsing -ContentType "application/json"
    foreach ($object in $ctv1DatatypeConfigurationResponse.value) {
        if ($object.properties.DataTypeId -eq "Daemons") {
            $ctv2JsonObject.resources[0].properties.dataSources.extensions[1].extensionSettings.enableServices = if ($object.Enabled -eq "false") { $false } else { $true }
        }
        if ($object.properties.DataTypeId -eq "Files") {
            $ctv2JsonObject.resources[0].properties.dataSources.extensions[1].extensionSettings.enableFiles = if ($object.Enabled -eq "false") { $false } else { $true }
            $ctv2JsonObject.resources[0].properties.dataSources.extensions[0].extensionSettings.enableFiles = if ($object.Enabled -eq "false") { $false } else { $true }
        }
        if ($object.properties.DataTypeId -eq "Inventory") {
            $ctv2JsonObject.resources[0].properties.dataSources.extensions[1].extensionSettings.enableInventory = if ($object.Enabled -eq "false") { $false } else { $true }
            $ctv2JsonObject.resources[0].properties.dataSources.extensions[0].extensionSettings.enableInventory = if ($object.Enabled -eq "false") { $false } else { $true }
        }
        if ($object.properties.DataTypeId -eq "Software") {
            $ctv2JsonObject.resources[0].properties.dataSources.extensions[1].extensionSettings.enableSoftware = if ($object.Enabled -eq "false") { $false } else { $true }
            $ctv2JsonObject.resources[0].properties.dataSources.extensions[0].extensionSettings.enableSoftware = if ($object.Enabled -eq "false") { $false } else { $true }
        }
        if ($object.properties.DataTypeId -eq "Registry") {
            $ctv2JsonObject.resources[0].properties.dataSources.extensions[0].extensionSettings.enableRegistry = if ($object.Enabled -eq "false") { $false } else { $true }
            $ctv2JsonObject.resources[0].properties.dataSources.extensions[1].extensionSettings.enableRegistry = $false
        }
        if ($object.properties.DataTypeId -eq "WindowsServices") {
            $ctv2JsonObject.resources[0].properties.dataSources.extensions[0].extensionSettings.enableServices = if ($object.Enabled -eq "false") { $false } else { $true }
        }
    }
}
#function to generate DCR arm template
function GetDcrArmTemplate {
    param (
        [Parameter(Mandatory = $true)][string] $paramDCRName,
        [Parameter(Mandatory = $true)][string] $paramWorkspaceId,
        [Parameter(Mandatory = $true)][string] $paramWorkspaceLocation
    )
    $schema = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    $contentVersion = "1.0.0.0"
    $dcrTemplate =
    [ordered]@{
        "`$schema" = $schema;
        contentVersion = "$contentVersion"
        parameters     = [ordered]@{
            dataCollectionRuleName = [ordered]@{
                type         = "string"
                metadata     = [ordered]@{
                    description = "Specifies the name of the data collection rule to create."
                }
                defaultValue = "$paramDCRName"
            }
            workspaceResourceId    = [ordered]@{
                type         = "string"
                metadata     = [ordered]@{
                    description = "Specifies the Azure resource ID of the Log Analytics workspace to use to store change tracking data."
                }
                defaultValue = "$paramWorkspaceId"
            }
            workspaceLocation      = [ordered]@{
                type         = "string"
                metadata     = [ordered]@{
                    description = "Specifies location of log analytic workspace"
                }
                defaultValue = "$paramWorkspaceLocation"
            }
        }

        resources      = @(
            [ordered]@{
                type       = "Microsoft.Insights/dataCollectionRules"
                apiVersion = "2022-06-01"
                name       = "[parameters('dataCollectionRuleName')]"
                location   = "[parameters('workspaceLocation')]"
                properties = [ordered]@{
                    description  = "Data collection rule for CT."
                    dataSources  = [ordered]@{
                        extensions = @(
                            [ordered]@{
                                streams           = @(
                                    "Microsoft-ConfigurationChange",
                                    "Microsoft-ConfigurationChangeV2",
                                    "Microsoft-ConfigurationData"
                                )
                                extensionName     = "ChangeTracking-Windows"
                                extensionSettings = [ordered]@{
                                    enableFiles                = $true
                                    enableSoftware             = $true
                                    enableRegistry             = $true
                                    enableServices             = $true
                                    enableInventory            = $true
                                    registrySettingsObjectList = [ordered]@{
                                        registryCollectionFrequency = 3000
                                        registryInfo                = @()
                                    }
                                    fileSettings               = [ordered]@{
                                        fileCollectionFrequency = 2700
                                        fileinfo                = @()
                                    }
                                    softwareSettings           = [ordered]@{
                                        softwareCollectionFrequency = 1800
                                    }
                                    inventorySettings          = [ordered]@{
                                        inventoryCollectionFrequency = 36000
                                    }
                                    servicesSettings           = [ordered]@{
                                        serviceCollectionFrequency = 1800
                                    }
                                }
                                name              = "CTDataSource-Windows"
                            },
                            [ordered]@{
                                streams           = @(
                                    "Microsoft-ConfigurationChange",
                                    "Microsoft-ConfigurationChangeV2",
                                    "Microsoft-ConfigurationData"
                                )
                                extensionName     = "ChangeTracking-Linux"
                                extensionSettings = [ordered]@{
                                    enableFiles       = $true
                                    enableSoftware    = $true
                                    enableRegistry    = $false
                                    enableServices    = $true
                                    enableInventory   = $true
                                    fileSettings      = [ordered]@{
                                        fileCollectionFrequency = 900
                                        fileInfo                = @()
                                    }
                                    softwareSettings  = [ordered]@{
                                        softwareCollectionFrequency = 300
                                    }
                                    inventorySettings = [ordered]@{
                                        inventoryCollectionFrequency = 36000
                                    }
                                    servicesSettings  = [ordered]@{
                                        serviceCollectionFrequency = 300
                                    }
                                }
                                name              = "CTDataSource-Linux"
                            }
                        )
                    }
                    destinations = [ordered]@{
                        logAnalytics = @(
                            [ordered]@{
                                workspaceResourceId = "[parameters('workspaceResourceId')]"
                                name                = "Microsoft-CT-Dest"
                            }
                        )
                    }
                    dataFlows    = @(
                        [ordered]@{
                            streams      = @(
                                "Microsoft-ConfigurationChange",
                                "Microsoft-ConfigurationChangeV2",
                                "Microsoft-ConfigurationData"
                            )
                            destinations = @(
                                "Microsoft-CT-Dest"
                            )
                        }
                    )
                }
            }
        )
    }
    $generatedDcr = New-Object -TypeName PSObject -Property $dcrTemplate
    return $generatedDcr
}

#start of script
Write-Host "SIGN IN TO YOUR ACCOUNT" -BackgroundColor white

# getting token
$token = GetAccessToken
$headers = @{
    Authorization = "Bearer " + $token[-1]
}

# creating DCR arm template pscustom object
$ctv2JsonObject = GetDcrArmTemplate -paramDCRName $OutputDCRName -paramWorkspaceId $OutputWorkspaceResourceId -paramWorkspaceLocation $OutputDCRLocation


try 
{
#parsing and migrating settings from LA workspace to DCR
GetWindowsRegistorySettings
GetWindowsFileSetting
GetWindowsTrackingServices
GetLinuxFileSettings
GetDataTypeConfiguration

# Convert the custom object to JSON
$dcrJson = ConvertTo-Json -InputObject $ctv2JsonObject -Depth 32 | %{
    [Regex]::Replace($_, 
        "\\u(?<Value>[a-zA-Z0-9]{4})", {
            param($m) ([char]([int]::Parse($m.Groups['Value'].Value,
                [System.Globalization.NumberStyles]::HexNumber))).ToString() } )} #https://stackoverflow.com/questions/47779157/convertto-json-and-convertfrom-json-with-special-characters/47779605#47779605



# Save the JSON content to a file at a given path
Set-Content -Path "${OutputDCRTemplateFolderPath}/output.json" -Value $dcrJson

#get pathtype(absolute or relative)
$pathtype = TestPathType -Path $OutputDCRTemplateFolderPath

# End of script
Write-Host "`nSuccess!" -ForegroundColor green
Write-Output "Check your output folder! ($($pathtype):  $($OutputDCRTemplateFolderPath))"
}
catch 
{
Write-Host "Error: $($_.Exception.Message)" -ForegroundColor red
}
