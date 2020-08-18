# Azure Monitor Community
![License](https://img.shields.io/badge/license-MIT-green.svg)

This public repo serves the Azure Monitor community. It contains log queries, workbooks, and alerts, shared to help Azure Monitor users make the most of it.

## Contents
**Queries** - copy and paste queries to your Log Analytics environment, or run on the [Log Analytics Demo Environment](https://portal.loganalytics.io/demo)

**Workbooks** - the workbooks in this repo can be deployed as ARM templates to your Azure Monitor environment

**Alerts** - the alerts in this repo are log-based, meaning they are in fact log queries. You can run them on the [Log Analytics Demo Environment](https://portal.loganalytics.io/demo) or use them to create and test alerts on your own environment

## Structure
| File/folder       | Description                                		            |
|-------------------|---------------------------------------------------------------|
| `Azure services`  | Queries, workbooks and alerts for specific Azure services		|
| `Scenarios`       | Queries, workbooks and alerts to handle common "How to's  	|
| `Solutions`	      | Queries, workbooks and alerts organized by solutions	    |
| `README.md`       | This README file  		                                    |
| `LICENSE`         | The license for this repo 		                            |

## Contributing
Anyone can contribute to the repo, you don't need to be a pro. Have an interesting query or workbook? fork this repo, add your content to your fork and submit a pull request.
See [Contributing](https://github.com/microsoft/AzureMonitorCommunity/blob/master/CONTRIBUTING.md) for more details.

## We use KQL
The content in this repo uses KQL (Kusto Query Language). To get started with queries see [this article](https://docs.microsoft.com/azure/azure-monitor/log-query/get-started-queries).

#### Need help writing queries?
This repo has many examples that you may want to edit to fit your exact scenario. If you're not sure how to do that - post your question on our [community forum](https://techcommunity.microsoft.com/t5/azure-monitor/bd-p/AzureMonitor).

## Have a wish or a question?
Use [Issues](https://github.com/microsoft/AzureMonitorCommunity/issues) to call us out on missing content or something else we should improve on, and check out the [FAQ page](https://github.com/microsoft/AzureMonitorCommunity/wiki/FAQ) for common questions & answers.

## Redistribution
Upon redistribution of this repo, please be respectful of the readers and authors of this documentation, and include a link to the [original repo master branch](https://github.com/microsoft/AzureMonitorCommunity).
