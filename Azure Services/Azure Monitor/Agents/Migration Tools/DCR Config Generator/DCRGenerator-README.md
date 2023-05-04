# Workspace Config to DCR: Migration Tool

## Overview 
1. The purpose of this script is to help users convert their Log Analytics agent configuration stored in workspaces to corresponding Data Collection Rules (DCR) configuration.
2. The script will take workspace info as input and produce two separate ARM templates (along with parameter files) 
to cover both Windows and Linux performance counters, Windows event logs and Linux syslog. *Note:* Additional configuration for Azure solutions or services (VM Insights, Sentinel, Defender for Servers) are not yet supported, and maybe available in future versions.
3. The intended use of the script for migration is to generate the corresponding DCR ARM templates, which must then be associated (via built-in policy) to machines running the Azure Monitor Agent. 
so users can use that for programmatic deployment of their new DCRs.


## Getting Started

These instructions will help you get started with running the Migration Tool script.

### Prerequisites/Setup

- Powershell version 7.1.3 or higher is recommended (minimum version 5.1)
- Primarily uses Az Powershell module to pull workspace agent configuration information
- User will need Read access for the specified workspace resource
- Connect-AzAccount and Select-AzSubscription will be used to set the context for the script to run so proper Azure credentials will be needed

## Running the application

**Parameters**  
	@@ -73,9 +73,10 @@ To install DCR Config Generator:
	| `WorkspaceName` | Yes | Name of the target workspace. |
	| `DCRName` | Yes | Name of the new DCR. |
	| `Location` | Yes | Region location for the new DCR. |
	| `GetDcrPayload` | No | When set, it generates additional DCR JSON files 
	| `FolderPath` | No | Path in which to save the ARM template files and JSON files (optional). By default, Azure Monitor uses the current directory. |  
	
- Instructions to Run the Script
	- Running the script is straightforward.  Use the script location along with at least the 5 required parameters.
	- Option #1:Outputs **ready-to-deploy ARM template files** only that will create the generated DCR in the specified subscription and resource group, when deployed.

	```powershell
	.\WorkspaceConfigToDCRMigrationTool.ps1 -SubscriptionId $subId -ResourceGroupName $rgName -WorkspaceName $workspaceName -DCRName $dcrName -Location $location -FolderPath $folderPath
	```
	- Option #2: Outputs **ready-to-deploy ARM template files** only that will create the generated DCR in the specified subscription and resource group, when deployed.

	```powershell
	.\WorkspaceConfigToDCRMigrationTool.ps1 -SubscriptionId $subId -ResourceGroupName $rgName -WorkspaceName $workspaceName -DCRName $dcrName -Location $location -FolderPath $folderPath
	```

- Output for the Script
	- There are two separate ARM templates that can be produced (based on agent configuration of the target workspace):
		- Windows ARM Template and Parameter Files: will be created if target workspace contains Windows Performance Counters and/or Windows Events
		- Linux ARM Template and Parameter Files: will be created if target workspace contains Linux Performance Counters and/or Linux Syslog Events


