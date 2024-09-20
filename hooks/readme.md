# Setup

The pre-commit hook validates the WDL and Dockstore .yaml syntax. 

The pre-push hook syncs the workflows with the Broad Methods Respository. The workflows are also published to [Dockstore](https://dockstore.org/) via a GitHub app connected to this GitHub repository. The main drawback to Dockstore however, is importing the workflows into Terra won't copy over the "Description"/documentation section of the workflow.

# pre-commit

This hook first runs [WOMtool](https://cromwell.readthedocs.io/en/stable/WOMtool/) to validate all .wdl files in the repository. It then validates the syntax of `.dockstore.yaml` with the Dockstore [command line tool](https://docs.dockstore.org/en/stable/advanced-topics/dockstore-cli/yaml-command-line-validator-tool.html).

# pre-push

This hook runs the Python script `broad_methods_sync`. The script first copies the markdown for each workflow into individual `.md` files within the `documentation` folder. Next, each workflow within the "cSplotch-Workflow" Method Repository namespace is updated along with its documentation. These "methods" (workflows) can be accessed via https://portal.firecloud.org/#methods.