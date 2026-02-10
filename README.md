# The Alistair Ross Blog Content

This repository contains content from my blog over at [thealistairross.co.uk](https://thealistairross.co.uk) and any other social media as I create more. This is primarily aimed at Microsoft Sentinel and the wider Microsoft Defender ecosystem.

## Contents

### [Analytic Rules](/Analytic%20Rules)

Custom Microsoft Sentinel analytic rules for threat detection.

- [Impossible Travel Detection](/Analytic%20Rules/Impossible%20Travel/README.md) — KQL query that detects suspicious and impossible travel scenarios based on sign-in locations and geographically feasible travel speeds.

### [Playbooks](/Playbooks/README.md)

Azure Logic App playbooks for security automation.

- [Microsoft 365 Defender - Post Vulnerabilities to Teams](/Playbooks/Microsoft_365_Defender-Post_Vulnerabilities_to_Teams/README.md) — Logic App that posts Microsoft Defender vulnerability alerts to a Microsoft Teams channel.

### [Power BI](/Power%20Bi)

Power BI reports for Azure operational insights.

- [Azure Monitor Agent Deployment Report](/Power%20Bi/Azure%20Monitor%20Agent%20Deployment%20Report/BlogPost.md) — Power BI report that visualises Azure Monitor Agent deployment status, image compatibility, and Azure Policy compliance across an entire Azure tenant using Azure Resource Graph.

### [Sentinel Entities](/Sentinel%20Entities/README.md)

A four-part blog series with deployable ARM templates covering Microsoft Sentinel entity mapping, cross-workspace entities, and entity-driven automation.

- [Entity Mapping](/Sentinel%20Entities/Mapping/README.md) — ARM templates for configuring entity mapping on analytic rules.
- [Entity Automation](/Sentinel%20Entities/Automation/README.md) — Logic App templates triggered by alerts, incidents, and entities for automated response workflows.

### [SOAR](/SOAR)

Security Orchestration, Automation, and Response templates.

- [Logic App Standard Templates](/SOAR/LogicApp-Standard/Template/) — ARM and Bicep templates for Logic App Standard workflows.

### [Solutions](/Solutions)

Microsoft Sentinel content solutions including data connectors, parsers, and solution metadata.

- [Squid Proxy](/Solutions/Squid%20Proxy/) — Data collection configuration for Squid Proxy logs.
- [Syslog Forwarder](/Solutions/Syslog%20Forwarder/) — Syslog forwarder data connector using Virtual Machine Scale Sets.

### [Toolshed](/Toolshed/README.md)

A collection of standalone scripts, queries, and modules that don't belong to a specific project.

- **[KQL Toolbox](/Toolshed/KQL%20Toolbox/README.md)** — Miscellaneous KQL queries and functions.
    - [The Luhn Algorithm and KQL](/Toolshed/KQL%20Toolbox/the%20Luhn%20Algorithm.txt) — KQL implementation of the Luhn checksum algorithm for validating identification numbers.
    - [Evaluate Column Sizes](/Toolshed/KQL%20Toolbox/Evaluate%20Column%20Sizes.txt) — KQL query to evaluate and report on column sizes within a Log Analytics table.
- **[Sentinel Toolbox](/Toolshed/Sentinel%20Toolbox/README.md)** — PowerShell scripts and tools for Microsoft Sentinel operations.
    - [Export Hunts](/Toolshed/Sentinel%20Toolbox/Export-Hunts.ps1) — PowerShell script to export Sentinel Hunts (Preview) to ARM templates.
    - [Copy Log Analytics Table](/Toolshed/Sentinel%20Toolbox/Copy-LogAnalyticsTable.ps1) — PowerShell script to copy Log Analytics table schemas to custom log tables.
    - [Sentinel Threat Intelligence Module](/Toolshed/Sentinel%20Toolbox/SentinelThreatIntelligence/README.MD) — PowerShell module for querying and deleting threat intelligence indicators via the Sentinel API.
    - [Analytics to Basic Log Template Generator](/Toolshed/Sentinel%20Toolbox/Analytics%20to%20Basic%20Log%20via%20KQL%20Transformation%20Template%20Generator/README.md) — Sentinel workbook that generates ARM templates to split data between Analytics and Basic Log tables using DCR transformations, reducing ingestion costs.
- **[Scripts](/Toolshed/Scripts/)** — Standalone PowerShell scripts for Azure operations.
    - [Get-ResourceTypeActions](/Toolshed/Scripts/Get-ResourceTypeActions/README.md) — PowerShell script that discovers all resource types in a scope — including extension providers — and retrieves their control plane and data plane operations.
- **[Azure Policy](/Toolshed/Azure%20Policy/policyDefinitions/Monitoring/)** — Custom Azure Policy definitions for monitoring.
- [Managed Identities Permissions Script](/Toolshed/AssignManagedIdentitiesPermissions.ps1) — PowerShell script to assign permissions to Azure Managed Identities.

## Disclaimer

This project is provided "as is" without warranty of any kind. The content represents personal work and opinions and does not reflect the views of Microsoft or any other organisation.

## License

This project is licensed under the [MIT License](LICENSE). This license applies to the original code and content in this repository only.

Microsoft Azure, Microsoft Sentinel, Power BI, and other Microsoft product names are trademarks of Microsoft Corporation. Third-party product names and logos referenced in this repository belong to their respective owners. 