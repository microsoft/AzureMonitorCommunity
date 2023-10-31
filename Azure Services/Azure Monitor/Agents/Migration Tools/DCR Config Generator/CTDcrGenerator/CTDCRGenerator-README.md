# Workspace Config to DCR: Migration Tool

## Overview 
1. The purpose of this script is to help users convert their ChangeTracking Log Analytics agent configuration stored in workspaces to corresponding Data Collection Rules (DCR) configuration.
2. The script will take workspace info as input and produce ARM template
3. The intended use of the script for migration is to generate the corresponding DCR ARM template, which must then be associated (via built-in policy) to machines running the Azure Monitor Agent. 
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
	| `InputWorkspaceResourceId` | Yes | ARM resource id of the Input workspace. |
	| `OutputWorkspaceResourceId` | Yes | ARM resource id of the target workspace. |
	| `OutputDCRName` | Yes | Name of the new DCR. |
	| `OutputDCRLocation` | Yes | Region location for the new DCR. |
	| `OutputDCRTemplateFolderPath` | Yes | Path in which to save the ARM template files and JSON files (optional). >By default . can be given to use current directory. |  
	
- Instructions to Run the Script
	- Running the script is straightforward.  Use the script location along with 5 required parameters.


- Output for the Script
	- There will be 1 ARM template which can be produced (based on agent configuration of the InputWorkspaceResourceId): 
		- Both Windows and Linux settings will be migrated in a single template.


