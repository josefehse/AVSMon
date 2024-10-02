# Ripley's "Believe it or Not" AVS Monitoring solution!

Welcome to AVS's Monitoring solution! This solution is designed to monitor the health of your AVS environment and provide you with insights on how to improve it.

## Table of Contents

## Prerequisites
    - Azure Subscription
    - Virtual Network (connected to AVS)
    - AVS Environment information

## Deployment

To deploy the solution, click the button below:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjosefehse%2FAVSMon%2Frefs%2Fheads%2Fmaster%2Fsetup%2Favsmon.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fjosefehse%2FAVSMon%2Frefs%2Fheads%2Fmaster%2Fsetup%2FcustomUI%2Fsetup.json)

Alternatively, the solution can be deployed by cloning the repository and using the Azure CLI:

```bash
   az group deployment -n <deployment-name> -g <resource-group> --template-file ./setup/avsmon.json 
```

or Powershell:
    
```powershell
    New-AzResourceGroupDeployment -Name <deployment-name> -ResourceGroupName <resourceGroup> -TemplateFile ./setup/avsmon.json 
```

## Architecture

Refer to the [Architecture](./docs/architecture.md) document for more information on the solution's architecture.

## Telemetry

Microsoft can correlate these resources used to support the deployments. Microsoft collects this information to provide the best experiences with their products and to operate their business. The telemetry is collected through customer usage attribution. The data is collected and governed by Microsoft's privacy policies, located at https://www.microsoft.com/trustcenter.

If you don't wish to send usage data to Microsoft, you can disable telemetry during setup. 

Project Bicep collects telemetry in some scenarios as part of improving the product.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.


