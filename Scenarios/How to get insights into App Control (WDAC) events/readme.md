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
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com/microsoft/AzureMonitorCommunity/master/Scenarios/How%20to%20get%20insights%20into%20App%20Control%20(WDAC)%20events/DCR-WDAC.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a>
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com/microsoft/AzureMonitorCommunity/master/Scenarios/How%20to%20get%20insights%20into%20App%20Control%20(WDAC)%20events/DCR-WDAC.json" target="_blank"><img src="https://aka.ms/deploytoazuregovbutton"/></a>

<br />
You can deploy the workbook by clicking on the buttons below:<br />
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com/microsoft/AzureMonitorCommunity/master/Scenarios/How%20to%20get%20insights%20into%20App%20Control%20(WDAC)%20events/workbook.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a>
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com/microsoft/AzureMonitorCommunity/master/Scenarios/How%20to%20get%20insights%20into%20App%20Control%20(WDAC)%20events/workbook.json" target="_blank"><img src="https://aka.ms/deploytoazuregovbutton"/></a>

<br /><br />
### Parameters to deploy DCR
** **
![Log Analytics ResID and Location](./picture/LogAnalytics.png)
** **
