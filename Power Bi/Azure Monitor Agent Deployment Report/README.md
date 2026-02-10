# Azure Monitor Agent Deployment Report

A Power BI report that provides comprehensive visibility into Azure Monitor Agent (AMA) deployment status, image compatibility, and Azure Policy compliance across your entire Azure tenant.

**Blog Post:** [TheAlistairRoss.co.uk - Azure Monitor Agent Deployment Report]()
## Overview

The Azure Monitor Agent replaces the legacy Microsoft Monitoring Agent (MMA). Tracking AMA deployment at scale is non-trivial — virtual machines span Azure Marketplace images, custom gallery images, attached disks, and Azure Arc-connected servers, each with different policy support characteristics.

This report queries Azure Resource Graph at the tenant scope and visualises:

- AMA deployment state across Windows and Linux VMs, VM Scale Sets, and Azure Arc machines
- Image categorisation (Marketplace, Custom Gallery, Attached, Azure Arc)
- Built-in Azure Policy support assessment for each marketplace image
- Policy assignment compliance status mapped to individual resources

## Prerequisites

| Requirement | Details |
|---|---|
| **Power BI Desktop** | Free — available from the [Microsoft Store](https://apps.microsoft.com/detail/9ntxr16hnw1t) or [Microsoft Download Center](https://www.microsoft.com/download/details.aspx?id=58494) |
| **Azure permissions** | The account used to refresh the report needs **Reader** (or equivalent) at the tenant root management group to enumerate all VMs, policy assignments, definitions, and policy states. Partial access will cause policy display names to render as resource IDs. |
| **Power BI Project support** | The report is saved as a `.pbip` (Power BI Project — Preview). Ensure your Power BI Desktop version supports this format. |

## Getting Started

1. Download and extract the `Azure Monitor Agent Deployment Report.zip` from this repository.
2. Open `Azure Monitor Agent Deployment Report.pbip` in Power BI Desktop.
3. Click **Refresh** — you will be prompted to sign in to Azure Resource Graph.
4. Select **Organizational account**, authenticate with a work account that has the required permissions, then click **Connect**.
5. Wait for the data to load. For environments with > 10,000 machines this can take several minutes due to Azure Resource Graph API throttling.

## Project Structure

This report is saved as a **Power BI Project (`.pbip`)**, which decomposes the `.pbix` binary into human-readable, version-controllable files.

```
Azure Monitor Agent Deployment Report.pbip          # Project entry point
├── Azure Monitor Agent Deployment Report.Report/    # Report layer (visuals, pages, bookmarks)
│   ├── definition.pbir                              # Report ↔ Semantic Model binding
│   └── definition/
│       ├── report.json                              # Report-level settings
│       └── pages/                                   # One folder per report page
│           └── <pageId>/page.json
├── Azure Monitor Agent Deployment Report.SemanticModel/  # Data model layer
│   ├── definition.pbism                             # Semantic model settings
│   ├── diagramLayout.json                           # Model diagram positions
│   ├── DAXQueries/                                  # Saved DAX queries
│   └── definition/
│       ├── model.tmdl                               # Model metadata (culture, query order, table refs)
│       ├── database.tmdl                            # Compatibility level (1600)
│       ├── relationships.tmdl                       # All inter-table relationships
│       └── tables/                                  # TMDL file per table (schema + M/DAX source)
└── Images/                                          # Screenshots used in documentation
```

## Report Pages

| # | Page | Description |
|---|------|-------------|
| 1 | **Azure Monitor Agent Deployment Overview** | High-level estate view showing AMA deployment counts and Azure Policy compliance across all subscriptions. |
| 2 | **Agent Distribution Matrix** | Subscription-level agent coverage with drill-down to resource group and individual resource. Rolls up a worst-case status: *Success* → *Agent Failures* → *Agents Missing*. |
| 3 | **Linux Azure Marketplace VM Images** | Interactive breakdown of Linux VMs deployed from Azure Marketplace with agent status and built-in policy support assessment. |
| 4 | **Windows Azure Marketplace VM Images** | Same as above for Windows VMs — evaluates publisher/offer/SKU against the built-in policy allowlist. |
| 5 | **Azure Custom Gallery Images** | VMs deployed from Azure Compute Gallery images. These require policy parameter overrides (image ID or evaluation flag). |
| 6 | **Azure Attached Images** | VMs without standard image references (e.g. migrated via Azure Migrate, Citrix VDI). |
| 7 | **Azure Arc Machines** | Azure Arc-connected servers. AMA deployment depends on a healthy Azure Arc agent; machines only appear after Arc onboarding. |
| 8 | **Azure Policy Compliance Matrix** | Policy-centric view showing assignment compliance, with a synthetic "No Policy Assignment" state for uncovered resources. |

All pages include collapsible slicer panels (hamburger menu icon, upper-left) for filtering by resource type, OS, subscription, etc.

## Data Model

### Data Source

All data is sourced from **Azure Resource Graph (ARG)** via the [Power BI ARG connector](https://learn.microsoft.com/azure/governance/resource-graph/power-bi-connector-quickstart), scoped to the tenant. Result truncation is disabled (`resultTruncated=false`) on every query so that environments beyond the default 1,000-row limit are fully represented.

An additional lookup table (`ResourceTypes`) is fetched from the [Microsoft FinOps toolkit on GitHub](https://github.com/microsoft/finops-toolkit) to provide friendly display names for resource types.

### Tables

| Table | Source | Purpose |
|---|---|---|
| **Resources** | ARG — `resources` | All VMs, VMSS, and Arc machines with image metadata (publisher, offer, SKU, imageId, imageType, osType). |
| **AzureMonitorAgents** | ARG — `resources` (extensions) | AMA extension instances joined back to their parent VM via `vMResourceId`. |
| **PolicyStates** | ARG — `policyresources` (policystates + policydefinitions) | Per-resource compliance state, filtered to policies whose rule references `AzureMonitorLinuxAgent` or `AzureMonitorWindowsAgent`. |
| **PolicyAssignments** | ARG — `policyresources` (policyassignments) | Assignments linked to AMA-related policy definitions, including scope and definition type. |
| **PolicyDefinitions** | ARG — `policyresources` (policydefinitions) | AMA-related policy definitions (display name + ID). |
| **PolicySetDefinitions** | ARG — `policyresources` (policysetdefinitions) | Initiatives containing AMA-related policies. |
| **PolicySetDefinitionsToPolicyDefinitions** | Derived from `PolicySetDefinitions` | Bridge table mapping initiatives to their constituent policy definitions (many-to-many). |
| **ResourcePolicyCompliance** | DAX calculated table | Unions `PolicyStates` with resources that have **no** policy assignment, tagging them as `"No Policy Assignment"`. Enables the compliance matrix to surface uncovered resources. |
| **ComplianceStates** | DAX `DATATABLE` | Dimension table with all eight compliance states and a sort order for consistent visual ordering. |
| **Subscriptions** | ARG — `resourcecontainers` | Subscription metadata including management group ancestry chain. |
| **ManagementGroups** | ARG — `resourcecontainers` | Management group hierarchy with `PATH()` / `PATHITEM()` DAX columns for up to 6 levels of drill-down. |
| **ResourceGroups** | ARG — `resourcecontainers` | Resource groups joined to subscriptions containing compute resources. |
| **ResourceTypes** | CSV from GitHub (FinOps toolkit) | Friendly singular/plural display names, descriptions, and icons for the three tracked resource types. |
| **Measure** | DAX calculated table (scaffold) | Central measure table housing all report-level DAX measures. |

### Relationships

```
ManagementGroups ──1:*── Subscriptions ──1:*── ResourceGroups ──1:*── Resources
                                                                         │
                                              AzureMonitorAgents ──1:1───┘  (vMResourceId → id)
                                                                         │
                                              PolicyStates ───────*:1────┘  (resourceId → id)
                                                    │
                        PolicyAssignments ──1:*─────┘  (policyAssignmentId)
                                │
                        PolicyDefinitions ──1:1─────── (policyDefinitionId)
                                │
PolicySetDefinitionsToPolicyDefinitions ──*:1── PolicySetDefinitions
                        │
                        └───────*:1── PolicyDefinitions

ResourcePolicyCompliance ──*:1── ComplianceStates  (complianceState)
Resources ──*:1── ResourceTypes  (type → ResourceType)
```

Several relationships use **bi-directional cross-filtering** (`crossFilteringBehavior: bothDirections`) to enable visuals to filter in both directions — notably `AzureMonitorAgents ↔ Resources` and `PolicyStates ↔ Resources`.

### Key Calculated Columns

| Table | Column | Logic |
|---|---|---|
| `Resources` | `HasMonitoringAgent` | Boolean — `TRUE` if a matching `AzureMonitorAgents` row exists for the VM. |
| `Resources` | `AgentState` | Returns the agent's `provisioningState` or `"No Agent"` if absent. |
| `Resources` | `imageType` | Categorises VMs as *Marketplace Gallery*, *Custom Gallery*, *Attached*, *Azure Arc*, or *Unknown* based on image reference properties. |
| `Resources` | `Azure VM Windows Supported Image` | Evaluates the VM's publisher/offer/SKU/location against the built-in Windows AMA policy allowlists, returning `TRUE` if it would be covered. |
| `Resources` | `Azure VM Linux Supported Image` | Same as above for Linux — covers Red Hat, SUSE, Canonical, Oracle, OpenLogic, AlmaLinux, Rocky Linux, Debian, and CBL-Mariner/Azure Linux. |
| `Resources` | `Policy Supported Image` | `OR()` of the Windows and Linux supported image columns. |
| `Resources` | `imageIdDisplay` | Parses ARM resource IDs for gallery images into a readable `Gallery • Image • vVersion` format. |
| `ManagementGroups` | `Level1`–`Level6` | `LOOKUPVALUE` + `PATHITEM` columns enabling a management group drill-down hierarchy. |

### Key Measures

| Measure | Purpose |
|---|---|
| `VM Count` | `DISTINCTCOUNT(Resources[id])` — total unique compute resources in the current filter context. |
| `Has Agent` | Count of distinct resources that have an AMA extension. |
| `No Agent` | `VM Count − Has Agent` — resources missing AMA. |
| `Agents Succeeded` | Count of AMA extensions in `Succeeded` provisioning state. |
| `Agents Failure` | Count of AMA extensions in a non-`Succeeded` provisioning state. |
| `Agent Coverage Status` | Hierarchical roll-up: *Success* (all agents succeeded) → *Agent Failures* (all present but some failing) → *Agents Missing* (some resources lack AMA). |
| `Policy Compliance Status` | Worst-case compliance state across all policies in scope, using a ranked `SWITCH` (Non-compliant > Compliant > Error > … > No Policy Assignment). |
| `Portal URL (by Level)` | Dynamically generates an Azure Portal hyperlink for the current drill-down level (subscription / resource group / resource). |
| `Total VMs Target` | Percentage of all VMs that have the AMA installed, ignoring the `HasMonitoringAgent` slicer so the KPI denominator stays constant. |

## Azure Resource Graph Queries

The semantic model executes the following ARG queries via Power Query (`AzureResourceGraph.Query`). All queries have `resultTruncated=false` to return the complete result set.


## Limitations

- **Permissions-dependent scope** — the report only returns resources visible to the authenticated account. Partial access will degrade policy display names to raw resource IDs.
- **No auto-update of policy allowlists** — the DAX columns that evaluate built-in policy support (`Azure VM Windows Supported Image`, `Azure VM Linux Supported Image`) are hard-coded lists extracted from the current policy definitions. When Microsoft updates the built-in policies with new images or regions, these columns must be manually updated.
- **Agent configuration not covered** — the report tracks AMA deployment and provisioning state only. Data collection rules, agent configuration, and data pipeline health are out of scope.
- **API throttling** — Azure Resource Graph throttles queries per tenant. Large environments will experience longer refresh times.
- **Point-in-time snapshot** — data reflects the state at the time of the last Power BI refresh, not real-time.

## Contributing

Feedback and contributions are welcome. Please open an issue or pull request in this repository.

## License

See the repository root [README](../../README.md) for license information.
