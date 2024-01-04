# Deploy the data collection rules

This script deploys the following:
1. Custom Log table called SquidProxy_CL (if not already deployed)
1. Up to two data collection rules, each with KQL transformations to filter and enrich the data.

Prior to deploying the resources, ensure you have:

1. A Log Analytics workspace
1. A Data collection endpoint
1. Squid proxy server

These all need to be in the same region.

If you have multiple proxy servers and want them to be indetified individually, deploy the data collection rule multple times, ensuring each has a unique **ProxyName** parameter value.

You can also choose which logs are collected (Access and cache, and what access logs are collected based on the Squid HTTP result code.)

To deploy to Azure, you can use the following deploy to Azure button:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FTheAlistairRoss%2FThe-Cloud-Brain-Dump%2FMain%2FSolutions%2FSquid%2520Proxy%2FData%2520Collection%2FV1%2FazureDeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FTheAlistairRoss%2FThe-Cloud-Brain-Dump%2FMain%2FSolutions%2FSquid%2520Proxy%2FData%2520Collection%2FV1%2FcreateUiDefinition.json)


After deployment, associate the data collection rule with named squid proxy server to start collecting data.