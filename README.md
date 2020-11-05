# Azure Monitor Community
![License](https://img.shields.io/badge/license-MIT-green.svg)

This public repo serves the Azure Monitor community. It contains log queries, workbooks, and alerts, shared to help Azure Monitor users make the most of it.

## Contents
**Queries** - copy and paste queries to your Log Analytics environment, or run on the [Log Analytics Demo Environment](https://portal.loganalytics.io/demo)

**Workbooks** - the workbooks in this repo can be deployed as ARM templates to your Azure Monitor environment

**Alerts** - the alerts in this repo are log-based, meaning they are in fact log queries. You can run them on the [Log Analytics Demo Environment](https://portal.loganalytics.io/demo) or use them to create and test alerts on your own environment

## Contributing
Anyone can contribute to the repo, you don't need to be a pro. Have an interesting query or workbook? fork this repo, add your content to your fork and submit a pull request.
See [Contributing](https://github.com/microsoft/AzureMonitorCommunity/blob/master/CONTRIBUTING.md) for more details.

### Top Contributor
The October top contributor is <a itemprop="image" href="https://github.com/dmauser"><img style="height:auto;" alt="Avatar" width="25" height="25" class="avatar avatar-user width-full border bg-white" src="https://user-images.githubusercontent.com/1745412/97993135-50cc8480-1dec-11eb-8812-e3f941b4b9bc.png" /></a> [Bruno Gabrielli (Brunoga-MS)](https://github.com/Brunoga-MS). Thanks Bruno!
<br/>

### What's new this month?
Great workbooks were added, such as [AntiMalware Assessment](https://github.com/microsoft/AzureMonitorCommunity/blob/17fff190f3ed350c25682c5d626a68cfb958f436/Azure%20Services/Azure%20Monitor/Workbooks/Antimalware%20Assessment.json) and [Azure Inventory](https://github.com/microsoft/AzureMonitorCommunity/tree/master/Azure%20Services/Azure%20Resource%20Graph/Workbooks) (based on Azure Resource Graph), as well as a lot of new queries for many Azure services. For more details see [our Wiki](https://github.com/microsoft/AzureMonitorCommunity/wiki).

Check out the [Azure Inventory workbook](https://github.com/microsoft/AzureMonitorCommunity/tree/master/Azure%20Services/Azure%20Resource%20Graph/Workbooks) (based on Azure Resource Graph)
</br>

![Azure Inventory with Azure Resource Graph](https://user-images.githubusercontent.com/1745412/98221176-fc461800-1f57-11eb-9c28-58948d5acf9e.gif)

</br>

and the [AntiMalware Assessment workbook](https://github.com/microsoft/AzureMonitorCommunity/blob/17fff190f3ed350c25682c5d626a68cfb958f436/Azure%20Services/Azure%20Monitor/Workbooks/Antimalware%20Assessment.json)
</br>

![Malware Assessment](https://user-images.githubusercontent.com/1745412/98221692-9e660000-1f58-11eb-9aae-d1a43088d409.gif)

### Top asks
[Here](https://github.com/microsoft/AzureMonitorCommunity/wiki/Top-asks) are some ideas on what other users are looking for.

## Structure
| File/folder       | Description                                		                |
|-------------------|---------------------------------------------------------------|
| `Azure services`  | Queries, workbooks and alerts for specific Azure services		  |
| `Scenarios`       | Queries, workbooks and alerts to handle common "How to's    	|
| `Solutions`	      | Queries, workbooks and alerts organized by solutions	        |
| `CONTRIBUTING.md` | On how to contribute to this repo                             |
| `LICENSE`         | The license for this repo 		                                |
| `README.md`       | This README file  		                                        |

## We use KQL
The content in this repo uses KQL (Kusto Query Language). To get started with queries see [this article](https://docs.microsoft.com/azure/azure-monitor/log-query/get-started-queries).

#### Need help writing queries?
This repo has many examples that you may want to edit to fit your exact scenario. If you're not sure how to do that - post your question on our [community forum](https://techcommunity.microsoft.com/t5/azure-monitor/bd-p/AzureMonitor).

## Have a wish or a question?
Use [Issues](https://github.com/microsoft/AzureMonitorCommunity/issues) to call us out on missing content or something else we should improve on, and check out the [FAQ page](https://github.com/microsoft/AzureMonitorCommunity/wiki/FAQ) for common questions & answers.

## Redistribution
Upon redistribution of this repo, please be respectful of the readers and authors of this documentation, and include a link to the [original repo master branch](https://github.com/microsoft/AzureMonitorCommunity).
