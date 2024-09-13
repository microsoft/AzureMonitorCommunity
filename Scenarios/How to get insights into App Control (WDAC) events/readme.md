# How to get insights into App Control (WDAC) events

This scenario gives you insights into App Control (WDAC) events collected from Windows machines. It consists of a Data Collection Rule (DCR) leveraged by the Azure Monitor Agent (AMA). The second part is a Azure Workbook which visualize data, collected by the AMA and stored to a Log Analytics Workspace.
<br />
<br />
### Change History
---

| Version | Date  | What |
| ------------- |-----| -----|
| v1.0|2024-04| first Version, publish DCR and Workbook |

<br /><br /><br />

### Try on Portal
You can deploy the DCR by clicking on the buttons below:<br />
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmicrosoft%2FAzureMonitorCommunity%2Fmaster%2FScenarios%2FHow%2520to%2520get%2520insights%2520into%2520App%2520Control%2520(WDAC)%2520events%2FDCR-WDAC.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a>
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmicrosoft%2FAzureMonitorCommunity%2Fmaster%2FScenarios%2FHow%2520to%2520get%2520insights%2520into%2520App%2520Control%2520(WDAC)%2520events%2FDCR-WDAC.json" target="_blank"><img src="https://aka.ms/deploytoazuregovbutton"/></a>

<br />
You can deploy the workbook by clicking on the buttons below:<br />
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmicrosoft%2FAzureMonitorCommunity%2Fmaster%2FScenarios%2FHow%2520to%2520get%2520insights%2520into%2520App%2520Control%2520(WDAC)%2520events%2Fworkbook.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a>
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmicrosoft%2FAzureMonitorCommunity%2Fmaster%2FScenarios%2FHow%2520to%2520get%2520insights%2520into%2520App%2520Control%2520(WDAC)%2520events%2Fworkbook.json" target="_blank"><img src="https://aka.ms/deploytoazuregovbutton"/></a>

<br /><br />
### Parameters to deploy DCR
** **
![Log Analytics ResID and Location](./picture/LogAnalytics.png)
** **
