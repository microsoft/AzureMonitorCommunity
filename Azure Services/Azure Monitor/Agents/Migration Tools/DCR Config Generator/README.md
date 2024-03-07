# Overview

1. The `workspaceConfigToDcrMigrationTool` or `DCR generator` in the context of MMA config to AMA config migration is a **powershell script**  that helps users convert their Log Analytics agent configuration stored in workspaces to corresponding Data Collection Rules (DCR) configuration.
It is a standalone script and doesn't require the installation of any additional dependencies.

2. The script will take the workspace information (subId, resourceGroup, workspaceName) as inputs and produce multiple **DCR ARM templates** (depending on the MMA configurations present on the workspace)


# How to run the script?

## Prerequisites\Setup

- `Powershell version 7.1.3` or higher is recommended (minimum version 5.1)
- Primarily uses `Az Powershell module` to pull workspace agent configuration information (https://learn.microsoft.com/en-us/powershell/azure/install-azps-windows?view=azps-11.0.0&tabs=powershell&pivots=windows-psgallery)
- User will need Read/Write access to the specified workspace resource
- Connect-AzAccount and Select-AzSubscription will be used to set the context for the script to run so proper Azure credentials will be needed

## Running the script

1. Download the script and run it:

```powershell
	.\WorkspaceConfigToDCRMigrationTool.ps1 -SubscriptionId $subId -ResourceGroupName $rgName -WorkspaceName $workspaceName -DCRName $dcrName -OutputFolder $outputFolderPath
```

| Name                    | Required  | Description                                                                   |
| ----------------------- |:---------:|:-----------------------------------------------------------------------------:|
| `SubscriptionId`        | YES       | This is the subscription ID of the workspace                                  |
| `ResourceGroupName`     | YES       | This is the resource Group of the workspace                                   |
| `WorkspaceName`         | YES       | This is the name of the workspace (Azure resource ids are case insensitive)   |
| `DCRName`               | YES       | The base name that will be used for each one the outputs DCRs                 |
| `OutputFolder`          | NO        | The output folder path. If not provided, the working directory path is used   |

3. Outputs:
 -  For each supported `DCR type`, the script produces a DCR ARM template (ready to be deployed) and a DCR payload (for users that don't need the arm template)

 - This is the list of currently supported DCR types:
  - **Windows** contains `WindowsPerfCounters` and `WindowsEventLogs` data sources only
  - **Linux** contains `LinuxPerfCounters` and `Syslog` data sources only
  - **Custom Logs** contains `logFiles` data sources only
  - **IIS Logs** contains `iisLogs` data sources only
  - **Extensions** contains `extensions` data sources only along with any associated perfCounters data sources
    - `VMInsights` 
    - PS: If you would like to add support for a new extension type, please reach out to us.

# Contacts
For any issues, please contact us at `amcsdev@microsoft.com`