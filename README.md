# Azure Monitor Community
![License](https://img.shields.io/badge/license-MIT-green.svg)

This public repo serves the Azure Monitor community. It contains log queries, workbooks and alerts, shared to help Azure Monitor users make the most of it.

## Contents

| File/folder       | Description                                		|
|-------------------|---------------------------------------------------|
| `Azure service`   | Queries, workbooks and alerts by Azure service	|
| `Solutions`	    | Queries, workbooks and alerts by solution			|
| `README.md`       | This README file  		                        |
| `LICENSE`         | The license for this repo 		                |

## Prerequisites

- Queries - there are no prerequisites!
You can run any query from this repo on the [Log Analytics Demo Environment](https://portal.loganalytics.io/demo) or on your own Log Analytics environment if you have one.
- Workbooks - the workbooks in this repo can be deployed as ARM templates to your own Azure Monitor environment.
- Alerts - the alerts in this repo are log-based, which means they are in fact log queries. You can run them on the [Log Analytics Demo Environment](https://portal.loganalytics.io/demo) or use them to create and test alerts on your own environment.

## Key concepts

The content in this repo uses KQL (Kusto Query Language). To get started with queries see [this article](https://docs.microsoft.com/azure/azure-monitor/log-query/get-started-queries).

## Contributing

We follow the [GitHub fork and pull model](https://help.github.com/articles/about-collaborative-development-models).
To contribute your own examples, first [fork this repo](https://help.github.com/articles/fork-a-repo/), submit any changes or additions to your forked repo, and then [submit a pull request](https://help.github.com/articles/about-pull-requests/).

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

## Redistribution

Upon redistribution of this repo, please be respectful of the readers and authors of this documentation, and include a link to the [original repo master branch](https://github.com/microsoft/AzureMonitorCommunity).
