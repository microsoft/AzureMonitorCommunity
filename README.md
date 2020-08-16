# Azure Monitor Community
![License](https://img.shields.io/badge/license-MIT-green.svg)

This public repo serves the Azure Monitor community. It contains log queries, workbooks, and alerts, shared to help Azure Monitor users make the most of it.

## Contents

| File/folder       | Description                                		            |
|-------------------|---------------------------------------------------------------|
| `Azure services`  | Queries, workbooks and alerts for specific Azure services		|
| `Scenarios`       | Queries, workbooks and alerts to handle common "How to's  	|
| `Solutions`	      | Queries, workbooks and alerts organized by solutions	    |
| `README.md`       | This README file  		                                    |
| `LICENSE`         | The license for this repo 		                            |

## Prerequisites

- Queries - there are no prerequisites!
You can run any query from this repo on the [Log Analytics Demo Environment](https://portal.loganalytics.io/demo) or on your own Log Analytics environment
- Workbooks - the workbooks in this repo can be deployed as ARM templates to your Azure Monitor environment
- Alerts - the alerts in this repo are log-based, meaning they are in fact log queries. You can run them on the [Log Analytics Demo Environment](https://portal.loganalytics.io/demo) or use them to create and test alerts on your own environment

## Contributing
Anyone can contribute to the repo, you don't need to be a pro.
#### What
Any query or workbook you find useful can benefit other users as well.
We also keep a list of the [top asks](https://github.com/microsoft/AzureMonitorCommunity/wiki/Top-asks), you may find it inspiring :)
#### How
We follow the [GitHub fork and pull model](https://help.github.com/articles/about-collaborative-development-models)
1. [Fork this repo](https://help.github.com/articles/fork-a-repo/) - just click the Fork button on the top right corner of this page

2. Update your forked repo - add examples, edit existing content

3. [Submit a pull request](https://help.github.com/articles/about-pull-requests/) from your repo
<img width="800" alt="PR" src="https://user-images.githubusercontent.com/1745412/89768775-be765680-db04-11ea-8742-8ff0c9554491.png">

### Contributor License Agreement CLA 
This project welcomes contributions and suggestions. Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

Any source code in this repository is licensed under the MIT license as found [here](LICENSE).

## We use KQL
The content in this repo uses KQL (Kusto Query Language). To get started with queries see [this article](https://docs.microsoft.com/azure/azure-monitor/log-query/get-started-queries).

#### Need help writing queries?
This repo has many examples that you may want to edit to fit your exact scenario. If you're not sure how to do that - post your question on our [community forum](https://techcommunity.microsoft.com/t5/azure-monitor/bd-p/AzureMonitor).

## Have a wish or a question?
Use [Issues](https://github.com/microsoft/AzureMonitorCommunity/issues) to call us out on missing content or something else we should improve on, and check out the [FAQ] page (https://github.com/microsoft/AzureMonitorCommunity/wiki/FAQ) for common questions & answers.

## Redistribution
Upon redistribution of this repo, please be respectful of the readers and authors of this documentation, and include a link to the [original repo master branch](https://github.com/microsoft/AzureMonitorCommunity).
