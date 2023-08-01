# Azure Application Gateway Insights #

-------------------------

## Author ##

[Bruno Gabrielli](mailto:bruno.gabrielli@microsoft.com)

## Purpose ##

This workbook is intended to ease your Insights look on the Azure Application Gateway. It contains several tiles organized in 3 main tabs:

- Firewall Log
- Access Log
- Performance Log

## Package ##

You should find the following structure and included files in the solution directory:

- AzureApplicationGatewayInsights.workbook: The workbook itself in gallery template format.

- AzureApplicationGatewayInsights.json: The workbook itself in ARM template format

## Prerequistes ##

In order to work, the workbook needs the activation of ***Back-end health and diagnostic logs for Application Gateway*** as documented at [this](https://docs.microsoft.com/en-us/azure/application-gateway/application-gateway-diagnostics?WT.mc_id=Portal-fx#diagnostic-logging) link.

## Available parameters ##

![Azure Application Gateway Insights Parameters](./.media/AAG_Parameters.PNG)

> **NOTE:**
If no data is available according to the parameter' settings, you will get a warning similar to the one below:

![No Data](./.media/AAG_NoData.PNG)

## Screenshots ##

The below screenshots, taken from my lab environment, resembles the tiles currently available in the workbook.

### Firewall Log Tab ###

![Count of request pies](./.media/AAG_FirewallLog_CountOfRequests.PNG)
![Blocked Requests by Rule Name](./.media/AAG_FirewallLog_BlockedRequestByRuleName.PNG)
![Blocked Requests by Type and Object](./.media/AAG_FirewallLog_BlockedRequestByTypeAndObject.PNG)
![Blocked Request details](./.media/AAG_FirewallLog_BlockedRequestDetails.PNG)
![Blocked Request details full](./.media/AAG_FirewallLog_BlockedRequestDetailsFull.PNG)

### Acces Log Tab ###

![Requests/min by URI](./.media/AAG_AccessLog_RequestMinByURI.PNG)
![Failed Requests by URI](./.media/AAG_AccessLog_FailedRequestsByURI.PNG)
![Failed Request by Back-End Pools](./.media/AAG_AccessLog_FailedRequestByBackEndPool.PNG)
![HTTP 502 Errors by Back-End Pools](./.media/AAG_AccessLog_Http502ByBackEndPools.PNG)

### Performance Log Tab ###

No screenshots available at the moment.