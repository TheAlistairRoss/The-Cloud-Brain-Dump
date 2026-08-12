"""
Generates LogAnalyticsV1TableWorkbook.json.

Run with: python build_workbook.py
This script exists only as a maintainability aid (avoids hand-escaping JSON/KQL).
The generated .json file is the actual artifact imported into Azure Workbooks.
"""
import json
import uuid

def g():
    return str(uuid.uuid4())

# ---------------------------------------------------------------------------
# Helper constructors
# ---------------------------------------------------------------------------

def text(md, name, style=None, cv=None):
    content = {"json": md}
    if style:
        content["style"] = style
    item = {"type": 1, "content": content, "name": name}
    if cv:
        item["conditionalVisibility"] = cv
    return item


def params_item(parameters, name, style="pills", query_type=0, resource_type="microsoft.operationalinsights/workspaces"):
    return {
        "type": 9,
        "content": {
            "version": "KqlParameterItem/1.0",
            "parameters": parameters,
            "style": style,
            "queryType": query_type,
            "resourceType": resource_type,
        },
        "name": name,
    }


def query_item(query, name, query_type, size=1, title=None, resource_type=None,
               cross_component=None, grid_settings=None, exported_parameters=None,
               export_field_name=None, export_parameter_name=None,
               visualization=None, no_data_message=None, show_border=True,
               time_context_param=None, show_refresh_button=False):
    content = {
        "version": "KqlItem/1.0",
        "query": query,
        "size": size,
        "queryType": query_type,
    }
    if title:
        content["title"] = title
    if resource_type:
        content["resourceType"] = resource_type
    if cross_component:
        content["crossComponentResources"] = cross_component
    if grid_settings:
        content["gridSettings"] = grid_settings
    if exported_parameters:
        content["exportedParameters"] = exported_parameters
    if export_field_name:
        content["exportFieldName"] = export_field_name
    if export_parameter_name:
        content["exportParameterName"] = export_parameter_name
    if visualization:
        content["visualization"] = visualization
    if no_data_message:
        content["noDataMessage"] = no_data_message
    if time_context_param:
        content["timeContextFromParameter"] = time_context_param
    if show_refresh_button:
        content["showRefreshButton"] = True
    item = {"type": 3, "content": content, "name": name}
    if show_border:
        item["styleSettings"] = {"showBorder": True}
    return item


def arm_template_item(label, template_uri, template_parameters, title, description, name, run_label="Deploy"):
    return {
        "type": 11,
        "content": {
            "version": "LinkItem/1.0",
            "style": "nav",
            "links": [
                {
                    "id": g(),
                    "linkTarget": "ArmTemplate",
                    "linkLabel": label,
                    "style": "primary",
                    "linkIsContextBlade": True,
                    "templateRunContext": {
                        "componentIdSource": "parameter",
                        "componentId": "ResourceGroupId",
                        "templateUriSource": "static",
                        "templateUri": template_uri,
                        "templateParameters": template_parameters,
                        "titleSource": "static",
                        "title": title,
                        "descriptionSource": "static",
                        "description": description,
                        "runLabelSource": "static",
                        "runLabel": run_label,
                    },
                }
            ],
        },
        "name": f"links - {name}",
    }


def arm_action_item(label, path, method, params, title, description, name, run_label, result_message):
    action_context = {
        "pathSource": "static",
        "path": path,
        "headers": [],
        "params": params,
        "httpMethod": method,
        "titleSource": "static",
        "title": title,
        "descriptionSource": "static",
        "description": description,
        "runLabelSource": "static",
        "runLabel": run_label,
        "resultMessage": result_message,
        "isLongOperation": True,
    }
    return {
        "type": 11,
        "content": {
            "version": "LinkItem/1.0",
            "style": "nav",
            "links": [
                {
                    "id": g(),
                    "cellValue": "{SelectedTableName}",
                    "linkTarget": "ArmAction",
                    "linkLabel": label,
                    "style": "primary",
                    "linkIsContextBlade": True,
                    "armActionContext": action_context,
                }
            ],
        },
        "name": f"links - {name}",
    }


def wizard_nav_item(name, links, cv):
    return {
        "type": 11,
        "content": {
            "version": "LinkItem/1.0",
            "style": "nav",
            "links": [
                {
                    "id": g(),
                    "cellValue": parameter_name,
                    "linkTarget": "parameter",
                    "linkLabel": label,
                    "subTarget": "true",
                    "style": style,
                }
                for label, parameter_name, style in links
            ],
        },
        "conditionalVisibility": cv,
        "name": f"links - {name}",
    }


def wizard_page(items, name, reveal_parameter=None):
    page = {
        "type": 12,
        "content": {
            "version": "NotebookGroup/1.0",
            "groupType": "editable",
            "loadType": "always",
            "exportParameters": True,
            "items": items,
        },
        "name": f"page - {name}",
    }
    if reveal_parameter:
        page["conditionalVisibility"] = {
            "parameterName": reveal_parameter,
            "comparison": "isEqualTo",
            "value": "true",
        }
    return page


def mode_group(items, name, value):
    return {
        "type": 12,
        "content": {
            "version": "NotebookGroup/1.0",
            "groupType": "editable",
            "loadType": "always",
            "exportParameters": True,
            "items": items,
        },
        "conditionalVisibility": {
            "parameterName": "DceMode",
            "comparison": "isEqualTo",
            "value": value,
        },
        "name": f"group - {name}",
    }


items = []

# ---------------------------------------------------------------------------
# Title
# ---------------------------------------------------------------------------
items.append(text(
    "# Log Analytics V1 Table Migration & DCR Wizard\n"
    "This workbook inventories Log Analytics custom tables, migrates **Classic / V1** tables so they can receive "
    "DCR-based ingestion, discovers DCRs already targeting each table, and generates a replacement DCR for the "
    "**Logs Ingestion API** without changing the destination table's existing column names.\n\n"
    "It does this by:\n"
    "1. Reading the table's *current* columns (which typically have legacy type-suffixes like `Computer_s`, `EventTime_t`).\n"
    "2. Building a DCR **input stream** using *clean* column names when they are unambiguous "
    "(suffix removed, e.g. `Computer`, `EventTime`).\n"
    "3. Adding a **transformation** (`project-rename`) that renames the clean input columns back to the "
    "original suffixed names, so the **output stream** matches the table's existing schema exactly - "
    "**no destination table changes required**. If suffix removal creates duplicate names, the wizard "
    "automatically uses the original unique column names in compatibility mode.\n\n"
    "> Table migration is one-way. Reference: "
    "[Custom logs migration guide](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/custom-logs-migrate) | "
    "[Data collection rule structure](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-structure) | "
    "[Data collection transformations](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-transformations)",
    "text - Title"
))

items.append(text(
    "**Legacy column suffix map** used to compute the clean input-stream column names and their DCR data types:\n\n"
    "| Suffix | Legacy meaning | DCR / KQL type |\n"
    "|---|---|---|\n"
    "| `_s` | string | `string` |\n"
    "| `_d` | number (double) | `real` |\n"
    "| `_b` | boolean | `boolean` |\n"
    "| `_g` | guid | `string` (Logs ingestion API stores/queries GUIDs as string) |\n"
    "| `_t` | datetime | `datetime` |\n\n"
    "Columns without a recognized suffix (e.g. `TimeGenerated`) are passed through unchanged. "
    "Reserved system columns (`_ResourceId`, `TenantId`, `Type`, `RawData`, etc.) are excluded automatically.",
    "text - Suffix map",
    style="info"
))

items.append(text(
    "### Workflow\n"
    "**1. Select a table**  ->  **2. Migrate / verify**  ->  **3. Inspect schema & existing DCRs**  ->  "
    "**4. Configure**  ->  **5. Review and deploy**\n\n"
    "This is a single, always-loaded workspace. Later sections unlock automatically as you complete each stage, "
    "so your selections remain available while you review or change earlier choices.",
    "text - workflow",
    style="info"
))

# ---------------------------------------------------------------------------
# Global parameters
# ---------------------------------------------------------------------------
global_params = [
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "ShowHelp",
        "label": "Show Help",
        "type": 10,
        "isRequired": True,
        "typeSettings": {"additionalResourceOptions": [], "showDefault": False},
        "jsonData": "[\r\n    {\"value\":\"true\", \"label\": \"Yes\", \"selected\": true},\r\n    {\"value\":\"false\", \"label\": \"No\", \"selected\": false}\r\n]",
    },
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "ApiVersion",
        "type": 1,
        "isHiddenWhenLocked": True,
        "criteriaData": [
            {"criteriaContext": {"operator": "Default", "resultValType": "static", "resultVal": "2023-09-01"}}
        ],
    },
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "MigrateApiVersion",
        "type": 1,
        "isHiddenWhenLocked": True,
        "criteriaData": [
            {"criteriaContext": {"operator": "Default", "resultValType": "static", "resultVal": "2025-07-01"}}
        ],
    },
]
for reveal_parameter in ("RevealStep2", "RevealStep3", "RevealStep4", "RevealStep5"):
    global_params.append({
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": reveal_parameter,
        "type": 1,
        "isHiddenWhenLocked": True,
        "criteriaData": [
            {"criteriaContext": {"operator": "Default", "resultValType": "static", "resultVal": "false"}}
        ],
    })
items.append(params_item(global_params, "parameters - Global"))

# ---------------------------------------------------------------------------
# STEP 1: Connect + inventory custom tables
# ---------------------------------------------------------------------------
step1_items = []

step1_items.append(text(
    "## 1. Connect & inventory custom tables\n"
    "The inventory includes **Classic** tables that require migration and DCR-based custom tables that might "
    "already have been migrated. Matching DCRs are correlated by output stream *and* workspace destination. "
    "This prevents a migrated table from disappearing from the wizard after its subtype changes.",
    "text - step1 intro", cv={"parameterName": "ShowHelp", "comparison": "isEqualTo", "value": "true"}
))

step1_params = [
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "Subscriptions", "type": 6,
        "isRequired": True, "multiSelect": True, "quote": "'", "delimiter": ",",
        "query": "resources\r\n| where type =~ \"microsoft.operationalinsights/workspaces\"\r\n| distinct subscriptionId",
        "crossComponentResources": ["value::all"],
        "typeSettings": {"additionalResourceOptions": ["value::all"]},
        "defaultValue": "value::all", "queryType": 1, "resourceType": "microsoft.resourcegraph/resources",
    },
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "Workspace", "type": 5,
        "isRequired": True,
        "query": (
            "resources\r\n| where type =~ \"microsoft.operationalinsights/workspaces\"\r\n"
            "| project id, name, subscriptionId, location\r\n"
            "| join kind = inner (\r\n"
            "    resourcecontainers\r\n"
            "    | where type == \"microsoft.resources/subscriptions\"\r\n"
            "    | project subscriptionId, subscription = strcat(name,\" (\",subscriptionId,\")\")\r\n"
            "    )\r\n"
            "on subscriptionId\r\n"
            "| project value = id, label = name, group = subscription"
        ),
        "crossComponentResources": ["{Subscriptions}"],
        "typeSettings": {"additionalResourceOptions": [], "showDefault": False},
        "queryType": 1, "resourceType": "microsoft.resourcegraph/resources",
    },
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "TimeRange", "label": "Time Range", "type": 4,
        "description": "Used to evaluate ingestion volume and last-ingested time per table",
        "isRequired": True,
        "typeSettings": {"selectableValues": [
            {"durationMs": 86400000}, {"durationMs": 259200000}, {"durationMs": 604800000},
            {"durationMs": 1209600000}, {"durationMs": 2592000000}, {"durationMs": 7776000000},
        ]},
        "value": {"durationMs": 604800000},
    },
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "ResourceGroupId", "type": 1,
        "query": "resources\r\n| where id =~ \"{Workspace}\"\r\n| project value = strcat(\"/subscriptions/\", subscriptionId, \"/resourceGroups/\", resourceGroup)",
        "crossComponentResources": ["{Subscriptions}"], "isHiddenWhenLocked": True,
        "queryType": 1, "resourceType": "microsoft.resourcegraph/resources",
    },
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "WorkspaceLocation", "type": 1,
        "query": "resources\r\n| where id =~ \"{Workspace}\"\r\n| project value = location",
        "crossComponentResources": ["{Subscriptions}"], "isHiddenWhenLocked": True,
        "queryType": 1, "resourceType": "microsoft.resourcegraph/resources",
    },
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "WorkspaceCustomerId", "type": 1,
        "query": "resources\r\n| where id =~ \"{Workspace}\"\r\n| project value = tostring(properties.customerId)",
        "crossComponentResources": ["{Subscriptions}"], "isHiddenWhenLocked": True,
        "queryType": 1, "resourceType": "microsoft.resourcegraph/resources",
    },
]
step1_items.append(params_item(step1_params, "parameters - Step1"))

# Query A: All custom log tables from ARM. The table type filter excludes
# Microsoft/system tables while retaining Classic and DCR-based custom tables.
q_tables_arm = (
    "{\"version\":\"ARMEndpoint/1.0\",\"data\":null,\"headers\":[],\"method\":\"GET\","
    "\"path\":\"{Workspace}/tables?api-version={ApiVersion}\",\"urlParams\":[],\"batchDisabled\":false,"
    "\"transformers\":[{\"type\":\"jsonpath\",\"settings\":{\"tablePath\":\"$.value[?(@.properties.schema.tableType == 'CustomLog')].properties\","
    "\"columns\":["
    "{\"path\":\"$.schema.name\",\"columnid\":\"name\",\"columnType\":\"string\"},"
    "{\"path\":\"$.schema.tableSubType\",\"columnid\":\"tableSubType\",\"columnType\":\"string\"},"
    "{\"path\":\"$.plan\",\"columnid\":\"plan\",\"columnType\":\"string\"},"
    "{\"path\":\"$.retentionInDays\",\"columnid\":\"retentionInDays\",\"columnType\":\"number\"}"
    "]}}]}"
)
step1_items.append(query_item(
    q_tables_arm, "query ResourceManager - CustomTables", query_type=12, size=0,
    title="Custom tables lookup (hidden helper)",
    grid_settings={"rowLimit": 1000}
) | {"conditionalVisibility": {"parameterName": "true", "comparison": "isEqualTo", "value": "false"}})

# Query B: Existing DCRs by destination table for the selected workspace.
q_dcr_inventory = (
    "resources\r\n"
    "| where type =~ \"microsoft.insights/datacollectionrules\"\r\n"
    "| extend DcrName = name, DcrId = id, DceId = tostring(properties.dataCollectionEndpointId)\r\n"
    "| mv-expand DataFlow = properties.dataFlows\r\n"
    "| extend OutputStream = tostring(DataFlow.outputStream)\r\n"
    "| where OutputStream startswith \"Custom-\"\r\n"
    "| mv-expand FlowDestination = DataFlow.destinations\r\n"
    "| mv-expand LogDestination = properties.destinations.logAnalytics\r\n"
    "| where tostring(FlowDestination) == tostring(LogDestination.name)\r\n"
    "| where tostring(LogDestination.workspaceResourceId) =~ \"{Workspace}\"\r\n"
    "| extend name = substring(OutputStream, 7)\r\n"
    "| summarize ExistingDcrCount = dcount(DcrId), DcrNames = make_set(DcrName) by name\r\n"
    "| extend ExistingDcrNames = strcat_array(DcrNames, \", \")\r\n"
    "| project-away DcrNames"
)
step1_items.append(query_item(
    q_dcr_inventory, "query ResourceGraph - DcrInventory", query_type=1, size=0,
    title="DCR destination lookup (hidden helper)",
    resource_type="microsoft.resourcegraph/resources", cross_component=["{Subscriptions}"],
    grid_settings={"rowLimit": 1000}
) | {"conditionalVisibility": {"parameterName": "true", "comparison": "isEqualTo", "value": "false"}})

# Query C: usage volumes per table
q_usage = (
    "let timeStart = {TimeRange:start};\r\n"
    "let timeEnd = {TimeRange:end};\r\n"
    "let timeStep = {TimeRange:grain};\r\n"
    "Usage\r\n"
    "| where TimeGenerated between (timeStart .. timeEnd)\r\n"
    "| make-series Trend = sum(Quantity) default = 0 on TimeGenerated "
    "from timeStart to timeEnd step timeStep by DataType\r\n"
    "| extend TotalMB = array_sum(Trend)\r\n"
    "| project DataType, TotalMB, Trend\r\n"
    "| order by TotalMB desc"
)
step1_items.append(query_item(
    q_usage, "query LogAnalytics - Usage", query_type=0, size=0,
    title="Ingestion volume and trend (hidden helper)",
    resource_type="microsoft.operationalinsights/workspaces", cross_component=["{Workspace}"],
    grid_settings={"rowLimit": 1000}, time_context_param="TimeRange",
    visualization="table"
) | {"conditionalVisibility": {"parameterName": "true", "comparison": "isEqualTo", "value": "false"}})

# Query D: The visible inventory performs both left-outer joins directly.
# Merge items only execute reliably when rendered, so there must be no hidden
# intermediate Merge item in this dependency chain.
dcr_merge_id = g()
usage_merge_id = g()
q_inventory_merge = (
    "{\"version\":\"Merge/1.0\",\"merges\":["
    "{\"id\":\"" + dcr_merge_id + "\",\"mergeType\":\"leftouter\","
    "\"leftTable\":\"query ResourceManager - CustomTables\",\"rightTable\":\"query ResourceGraph - DcrInventory\","
    "\"leftColumn\":\"name\",\"rightColumn\":\"name\"},"
    "{\"id\":\"" + usage_merge_id + "\",\"mergeType\":\"leftouter\","
    "\"leftTable\":\"query ResourceManager - CustomTables\",\"rightTable\":\"query LogAnalytics - Usage\","
    "\"leftColumn\":\"name\",\"rightColumn\":\"DataType\"}],"
    "\"projectRename\":["
    "{\"originalName\":\"[query ResourceManager - CustomTables].name\",\"mergedName\":\"name\",\"fromId\":\"" + usage_merge_id + "\"},"
    "{\"originalName\":\"[query ResourceManager - CustomTables].name\",\"mergedName\":\"DcrJoinTableName\",\"fromId\":\"" + dcr_merge_id + "\"},"
    "{\"originalName\":\"[query ResourceGraph - DcrInventory].name\",\"mergedName\":\"DcrMatchedTableName\",\"fromId\":\"" + dcr_merge_id + "\"},"
    "{\"originalName\":\"[query LogAnalytics - Usage].DataType\",\"mergedName\":\"UsageDataType\",\"fromId\":\"" + usage_merge_id + "\"},"
    "{\"originalName\":\"[query ResourceManager - CustomTables].tableSubType\",\"mergedName\":\"tableSubType\",\"fromId\":\"" + usage_merge_id + "\"},"
    "{\"originalName\":\"[query ResourceGraph - DcrInventory].ExistingDcrCount\",\"mergedName\":\"ExistingDcrCount\",\"fromId\":\"" + dcr_merge_id + "\"},"
    "{\"originalName\":\"[query ResourceGraph - DcrInventory].ExistingDcrNames\",\"mergedName\":\"ExistingDcrNames\",\"fromId\":\"" + dcr_merge_id + "\"},"
    "{\"originalName\":\"[query ResourceManager - CustomTables].plan\",\"mergedName\":\"plan\",\"fromId\":\"" + usage_merge_id + "\"},"
    "{\"originalName\":\"[query ResourceManager - CustomTables].retentionInDays\",\"mergedName\":\"retentionInDays\",\"fromId\":\"" + usage_merge_id + "\"},"
    "{\"originalName\":\"[query LogAnalytics - Usage].TotalMB\",\"mergedName\":\"TotalMB\",\"fromId\":\"" + usage_merge_id + "\"},"
    "{\"originalName\":\"[query LogAnalytics - Usage].Trend\",\"mergedName\":\"Trend\",\"fromId\":\"" + usage_merge_id + "\"}"
    "]}"
)
step1_items.append(query_item(
    q_inventory_merge, "query Merge - MigrationInventory", query_type=7, size=1,
    title="Custom table migration inventory - select a table",
    no_data_message="No custom log tables were found in the selected workspace.",
    grid_settings={
        "rowLimit": 1000, "filter": True,
        "formatters": [
            {"columnMatch": "tableSubType", "formatter": 18,
             "formatOptions": {"thresholdsOptions": "colors", "thresholdsGrid": [
                 {"operator": "==", "thresholdValue": "Classic", "representation": "redBright", "text": "{0}{1}"},
                 {"operator": "Default", "thresholdValue": None, "representation": "green", "text": "{0}{1}"},
             ]}},
            {
                "columnMatch": "ExistingDcrCount",
                "formatter": 0,
                "numberFormat": {
                   "unit": 0,
                   "options": {"style": "decimal"},
                   "emptyValCustomText": "0",
                },
            },
            {"columnMatch": "TotalMB", "formatter": 4,
             "formatOptions": {"palette": "blue"},
             "numberFormat": {
                 "unit": 38,
                 "options": {"style": "decimal", "maximumFractionDigits": 2},
                 "emptyValCustomText": "0",
             }},
            {"columnMatch": "Trend", "formatter": 21,
             "formatOptions": {"palette": "blue"}},
            {"columnMatch": "DcrMatchedTableName", "formatter": 5},
            {"columnMatch": "UsageDataType", "formatter": 5},
        ],
        "labelSettings": [
            {"columnId": "name", "label": "Table Name"},
            {"columnId": "tableSubType", "label": "Migration state"},
            {"columnId": "ExistingDcrCount", "label": "Matching DCRs"},
            {"columnId": "ExistingDcrNames", "label": "DCR names"},
            {"columnId": "plan", "label": "Plan"},
            {"columnId": "retentionInDays", "label": "Retention (days)"},
            {"columnId": "TotalMB", "label": "Ingestion volume"},
            {"columnId": "Trend", "label": "Ingestion trend"},
        ],
    },
    exported_parameters=[
        {"fieldName": "name", "parameterName": "SelectedTableName", "parameterType": 1},
        {"fieldName": "tableSubType", "parameterName": "SelectedTableSubType", "parameterType": 1},
        {"fieldName": "plan", "parameterName": "SelectedTablePlan", "parameterType": 1},
        {"fieldName": "TotalMB", "parameterName": "SelectedTableTotalMB", "parameterType": 1},
    ],
    show_refresh_button=True
))

step1_items.append(text(
    "**Migration state:** `Classic` requires the one-way migration in Step 2. A non-Classic custom table is "
    "already DCR-capable; legacy-suffixed columns or an existing matching DCR make it a likely former V1 table. "
    "Use the grid's **Refresh** button after migration, then reselect the same table.",
    "text - step1 tip", style="info", cv={"parameterName": "ShowHelp", "comparison": "isEqualTo", "value": "true"}
))

step1_items.append(text(
    "No table is selected yet - select a row in the grid above (**Step 1 result**) to continue.",
    "text - step1 noselection", style="warning",
    cv={"parameterName": "SelectedTableName", "comparison": "isEqualTo", "value": ""}
))

step1_page_items = [text(
    "# 1 | Select a custom table\n"
    "Choose a workspace, compare migration and DCR status, then select a table.",
    "text - section 1",
    style="info"
)]
step1_page_items.extend(step1_items)
step1_page_items.append(wizard_nav_item(
    "Step1 Next",
    [("Next: reveal migrate or verify below", "RevealStep2", "primary")],
    {"parameterName": "SelectedTableName", "comparison": "isNotEqualTo", "value": ""},
))
items.append(wizard_page(step1_page_items, "Select table"))

# ---------------------------------------------------------------------------
# STEP 2: Migrate or verify table readiness
# ---------------------------------------------------------------------------
q_table_details = (
    "{\"version\":\"ARMEndpoint/1.0\",\"data\":null,\"headers\":[],\"method\":\"GET\","
    "\"path\":\"{Workspace}/tables/{SelectedTableName}?api-version={ApiVersion}\",\"urlParams\":[],"
    "\"batchDisabled\":false,\"transformers\":null}"
)

table_state_parameters = [
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "SelectedTableDetails",
        "type": 1,
        "query": q_table_details,
        "isHiddenWhenLocked": True,
        "queryType": 12,
    },
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "SelectedTableSubTypeLive",
        "type": 1,
        "query": (
            "let details = todynamic(base64_decode_tostring(\"{SelectedTableDetails:base64}\"));\r\n"
            "print value = tostring(details.properties.schema.tableSubType)"
        ),
        "crossComponentResources": ["{Workspace}"],
        "isHiddenWhenLocked": True,
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
    },
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "TableDcrReady",
        "type": 1,
        "query": (
            "let subtype = \"{SelectedTableSubTypeLive}\";\r\n"
            "print value = tolower(tostring(isnotempty(subtype) and subtype != \"Classic\"))"
        ),
        "crossComponentResources": ["{Workspace}"],
        "isHiddenWhenLocked": True,
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
    },
]

step2_items = [
    params_item(table_state_parameters, "parameters - Selected Table State"),
    text(
        "## 2. Migrate or verify the selected table\n"
        "Live subtype: **{SelectedTableSubTypeLive}**. Classic tables cannot be DCR output destinations until "
        "the table migrate operation enables DCR-based custom-log features.",
        "text - step2 migration intro"
    ),
    text(
        "### Migration impact - read before continuing\n"
        "- Migration is **one-way**.\n"
        "- MMA custom text logs can no longer write to the migrated table.\n"
        "- Existing HTTP Data Collector API ingestion may continue only for existing columns; schema changes can "
        "break legacy ingestion.\n"
        "- Stop legacy senders and switch to the Logs Ingestion API as part of the same change window.\n\n"
        "The action requires `Microsoft.OperationalInsights/workspaces/tables/migrate/action`, included in the "
        "**Log Analytics Contributor** role.",
        "text - step2 migration warning",
        style="warning",
        cv={"parameterName": "SelectedTableSubTypeLive", "comparison": "isEqualTo", "value": "Classic"}
    ),
    arm_action_item(
        label="Migrate table to DCR-based ingestion",
        path="{Workspace}/tables/{SelectedTableName}/migrate",
        method="POST",
        params=[{"key": "api-version", "value": "{MigrateApiVersion}"}],
        title="Migrate {SelectedTableName}",
        description=(
            "This one-way operation converts **{SelectedTableName}** from a Classic custom table to a DCR-based "
            "custom table. Confirm that MMA custom text collection is no longer required and that legacy HTTP "
            "Data Collector API senders are ready to be replaced."
        ),
        name="MigrateTable",
        run_label="Migrate table",
        result_message=(
            "Migration request for {SelectedTableName} completed. Refresh the Step 1 inventory and reselect the "
            "table to continue."
        ),
    ) | {"conditionalVisibility": {
        "parameterName": "SelectedTableSubTypeLive", "comparison": "isEqualTo", "value": "Classic"
    }},
    text(
        "**After migration succeeds:** use the **Refresh** button on the Step 1 inventory and reselect "
        "`{SelectedTableName}`. The table remains in the unified inventory with its new subtype.",
        "text - step2 migration refresh",
        style="info",
        cv={"parameterName": "SelectedTableSubTypeLive", "comparison": "isEqualTo", "value": "Classic"}
    ),
    text(
        "**Ready:** `{SelectedTableName}` is already DCR-capable. Continue to inspect its schema and any DCRs "
        "currently targeting it.",
        "text - step2 ready",
        style="success",
        cv={"parameterName": "TableDcrReady", "comparison": "isEqualTo", "value": "true"}
    ),
]

step2_visibility = {"parameterName": "SelectedTableName", "comparison": "isNotEqualTo", "value": ""}
step2_page_items = [text(
    "# 2 | Migrate or verify\n"
    "Classic tables must be migrated before Azure accepts a DCR that targets them.",
    "text - section 2",
    style="warning",
)]
for item in step2_items:
    if "conditionalVisibility" not in item:
        item["conditionalVisibility"] = step2_visibility
step2_page_items.extend(step2_items)
step2_page_items.append(wizard_nav_item(
    "Step2 Next",
    [("Next: reveal schema and existing DCRs below", "RevealStep3", "primary")],
    {"parameterName": "TableDcrReady", "comparison": "isEqualTo", "value": "true"},
))
items.append(wizard_page(step2_page_items, "Migrate or verify", "RevealStep2"))

# ---------------------------------------------------------------------------
# STEP 3: Inspect schema, discover DCRs, compute artifacts
# ---------------------------------------------------------------------------
step3_schema_items = []
step3_schema_items.append(text(
    "## 3. Inspect the table schema and existing DCRs\n"
    "This reads the *live* column list for the selected table and computes:\n"
    "- **CleanName** - the column name with any legacy type-suffix removed.\n"
    "- **MappedType** - the KQL/DCR data type for that input column.\n"
    "- Whether two or more columns collapse to the same `CleanName` (a **collision**).\n"
    "- **InputName** - the actual DCR input column. If any collision exists, the workbook safely retains all "
    "original unique names instead of blocking deployment.",
    "text - step3 schema intro"
))

kql_schema_display = (
    "let tableDetails = todynamic(base64_decode_tostring(\"{SelectedTableDetails:base64}\"));\r\n"
    "let cols = tableDetails.properties.schema.columns;\r\n"
    "let reserved = dynamic([\"_ResourceId\",\"id\",\"_SubscriptionId\",\"TenantId\",\"Type\",\"UniqueId\",\"Title\",\"RawData\",\"tenant\",\"MG\",\"ManagementGroupName\",\"SourceSystem\"]);\r\n"
    "let tableColumns = print col = cols\r\n"
    "    | mv-expand col\r\n"
    "    | project Name = tostring(col.name), Type = tostring(col.type);\r\n"
    "let base = union tableColumns, (\r\n"
    "    print Name = \"TimeGenerated\", Type = \"datetime\"\r\n"
    "    | where toscalar(tableColumns | where Name =~ \"TimeGenerated\" | count) == 0)\r\n"
    "    | where Name !in~ (reserved)\r\n"
    "    | extend Suffix = extract(@'_(s|d|b|g|t)$', 1, Name)\r\n"
    "    | extend Base = extract(@'^(.*)_(?:s|d|b|g|t)$', 1, Name)\r\n"
    "    | extend CleanName = iif(isempty(Base), Name, Base)\r\n"
    "    | extend MappedType = case(Suffix == \"s\", \"string\", Suffix == \"d\", \"real\", Suffix == \"b\", \"boolean\", Suffix == \"g\", \"string\", Suffix == \"t\", \"datetime\", Type =~ \"datetime\", \"datetime\", Type =~ \"guid\", \"string\", tolower(Type));\r\n"
    "let collisionCount = toscalar(base | summarize Cnt = count() by CleanName | where Cnt > 1 | summarize TotalCollisions = count());\r\n"
    "base\r\n"
    "| join kind=leftouter (\r\n"
    "    base\r\n"
    "    | summarize DuplicateCount = count() by CleanName\r\n"
    "    ) on CleanName\r\n"
    "| extend Collision = DuplicateCount > 1\r\n"
    "| extend InputName = iif(collisionCount > 0, Name, CleanName)\r\n"
    "| extend Resolution = iif(collisionCount > 0, \"Compatibility mode - original names retained\", \"Clean-name mode\")\r\n"
    "| project Name, Type, CleanName, InputName, MappedType, Collision, Resolution\r\n"
    "| order by Collision desc, CleanName asc"
)
step3_schema_items.append(query_item(
    kql_schema_display, "query LogAnalytics - SchemaClean", query_type=0, size=1,
    title="Current columns -> DCR input-stream mapping",
    resource_type="microsoft.operationalinsights/workspaces", cross_component=["{Workspace}"],
    grid_settings={
        "rowLimit": 500, "filter": True,
        "formatters": [
            {"columnMatch": "Collision", "formatter": 18, "formatOptions": {
                "thresholdsOptions": "colors", "thresholdsGrid": [
                    {"operator": "==", "thresholdValue": "true", "representation": "redBright", "text": "{0}{1}"},
                    {"operator": "Default", "thresholdValue": None, "representation": "green", "text": "{0}{1}"},
                ]}},
        ],
    },
))

# Compute all DCR artifacts once as a JSON object. Hidden text parameters then
# extract each value automatically, avoiding row-selection exports.
kql_build_artifacts = (
    "let tableDetails = todynamic(base64_decode_tostring(\"{SelectedTableDetails:base64}\"));\r\n"
    "let cols = tableDetails.properties.schema.columns;\r\n"
    "let reserved = dynamic([\"_ResourceId\",\"id\",\"_SubscriptionId\",\"TenantId\",\"Type\",\"UniqueId\",\"Title\",\"RawData\",\"tenant\",\"MG\",\"ManagementGroupName\",\"SourceSystem\"]);\r\n"
    "let tableColumns = print col = cols\r\n"
    "    | mv-expand col\r\n"
    "    | project Name = tostring(col.name), Type = tostring(col.type);\r\n"
    "let base = union tableColumns, (\r\n"
    "    print Name = \"TimeGenerated\", Type = \"datetime\"\r\n"
    "    | where toscalar(tableColumns | where Name =~ \"TimeGenerated\" | count) == 0)\r\n"
    "    | where Name !in~ (reserved)\r\n"
    "    | extend Suffix = extract(@'_(s|d|b|g|t)$', 1, Name)\r\n"
    "    | extend Base = extract(@'^(.*)_(?:s|d|b|g|t)$', 1, Name)\r\n"
    "    | extend CleanName = iif(isempty(Base), Name, Base)\r\n"
    "    | extend MappedType = case(Suffix == \"s\", \"string\", Suffix == \"d\", \"real\", Suffix == \"b\", \"boolean\", Suffix == \"g\", \"string\", Suffix == \"t\", \"datetime\", Type =~ \"datetime\", \"datetime\", Type =~ \"guid\", \"string\", tolower(Type));\r\n"
    "let collisionCount = toscalar(base | summarize Cnt = count() by CleanName | where Cnt > 1 | summarize TotalCollisions = count());\r\n"
    "let mapped = base | extend InputName = iif(collisionCount > 0, Name, CleanName);\r\n"
    "let inputColumnsJson = toscalar(\r\n"
    "    mapped\r\n"
    "    | extend ColJson = strcat('{\"name\":\"', InputName, '\",\"type\":\"', MappedType, '\"}')\r\n"
    "    | summarize Json = strcat(\"[\", strcat_array(make_list(ColJson), \",\"), \"]\")\r\n"
    "    | project Json);\r\n"
    "let renameText = toscalar(\r\n"
    "    mapped\r\n"
    "    | where InputName != Name\r\n"
    "    | extend RenameEntry = strcat(Name, \" = \", InputName)\r\n"
    "    | summarize Txt = strcat_array(make_list(RenameEntry), \",\\n    \")\r\n"
    "    | project Txt);\r\n"
    "let renameKql = iif(isempty(renameText), \"source\", strcat(\"source\\n| project-rename\\n    \", renameText));\r\n"
    "let transformKql = strcat(renameKql, \"\\n| extend TimeGenerated = coalesce(todatetime(TimeGenerated), now())\");\r\n"
    "print value = tostring(bag_pack("
    "\"HasCollisions\", tolower(tostring(collisionCount > 0)), "
    "\"CollisionCount\", tostring(collisionCount), "
    "\"LegacySuffixColumnCount\", tostring(toscalar(base | summarize countif(isnotempty(Suffix)))), "
    "\"InputColumnsJson\", inputColumnsJson, "
    "\"TransformKqlText\", transformKql))"
)

def artifact_value_query(property_name):
    return (
        "let artifacts = todynamic(base64_decode_tostring(\"{DcrArtifacts:base64}\"));\r\n"
        f"print value = tostring(artifacts.{property_name})"
    )

artifact_parameters = [
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "DcrArtifacts",
        "type": 1,
        "query": kql_build_artifacts,
        "crossComponentResources": ["{Workspace}"],
        "isHiddenWhenLocked": True,
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
    },
]
for parameter_name in (
    "HasCollisions", "CollisionCount", "LegacySuffixColumnCount", "InputColumnsJson", "TransformKqlText"
):
    artifact_parameters.append({
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": parameter_name,
        "type": 1,
        "query": artifact_value_query(parameter_name),
        "crossComponentResources": ["{Workspace}"],
        "isHiddenWhenLocked": True,
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
    })
artifact_parameters.append({
    "id": g(),
    "version": "KqlParameterItem/1.0",
    "name": "ConfigurationReady",
    "type": 1,
    "query": (
        "print value = tolower(tostring("
        "\"{TableDcrReady}\" == \"true\" and isnotempty(\"{InputColumnsJson:base64}\")))"
    ),
    "crossComponentResources": ["{Workspace}"],
    "isHiddenWhenLocked": True,
    "queryType": 0,
    "resourceType": "microsoft.operationalinsights/workspaces",
})

step3_schema_items.append(params_item(artifact_parameters, "parameters - DCR Artifacts"))

step3_schema_items.append(text(
    "**Legacy V1 evidence:** `{LegacySuffixColumnCount}` non-system column(s) use a recognized legacy type "
    "suffix. For a DCR-based table, this is evidence that the schema may have originated from Classic ingestion, "
    "but Azure does not expose durable pre-migration history.",
    "text - step3 legacy evidence",
    style="info"
))

step3_schema_items.append(text(
    "**Compatibility mode applied:** {CollisionCount} clean column name(s) are ambiguous (for example, "
    "`Computer_s` and `Computer_d` both become `Computer`). The source table cannot be changed, so the generated "
    "DCR input stream retains the table's original unique column names for every field. No table schema change is "
    "required, and deployment can continue. Your Logs Ingestion API payload must use the original suffixed names "
    "shown in **InputName**. To use clean names instead, resolve the ambiguity in the sending application before "
    "calling the API.",
    "text - step3 collision warning", style="warning",
    cv={"parameterName": "HasCollisions", "comparison": "isEqualTo", "value": "true"}
))

q_selected_dcrs = (
    "resources\r\n"
    "| where type =~ \"microsoft.insights/datacollectionrules\"\r\n"
    "| extend DcrName = name, DcrResourceId = id, DceResourceId = tostring(properties.dataCollectionEndpointId)\r\n"
    "| mv-expand DataFlow = properties.dataFlows\r\n"
    "| where tostring(DataFlow.outputStream) =~ strcat(\"Custom-\", \"{SelectedTableName}\")\r\n"
    "| mv-expand FlowDestination = DataFlow.destinations\r\n"
    "| mv-expand LogDestination = properties.destinations.logAnalytics\r\n"
    "| where tostring(FlowDestination) == tostring(LogDestination.name)\r\n"
    "| where tostring(LogDestination.workspaceResourceId) =~ \"{Workspace}\"\r\n"
    "| project ['DCR name'] = DcrName, ['DCR resource ID'] = DcrResourceId, "
    "['DCE resource ID'] = DceResourceId, ['Input streams'] = strcat_array(DataFlow.streams, \", \"), "
    "['Transformation'] = tostring(DataFlow.transformKql), ['Output stream'] = tostring(DataFlow.outputStream)"
)
q_existing_dcr_count = (
    "resources\r\n"
    "| where type =~ \"microsoft.insights/datacollectionrules\"\r\n"
    "| mv-expand DataFlow = properties.dataFlows\r\n"
    "| where tostring(DataFlow.outputStream) =~ strcat(\"Custom-\", \"{SelectedTableName}\")\r\n"
    "| mv-expand FlowDestination = DataFlow.destinations\r\n"
    "| mv-expand LogDestination = properties.destinations.logAnalytics\r\n"
    "| where tostring(FlowDestination) == tostring(LogDestination.name)\r\n"
    "| where tostring(LogDestination.workspaceResourceId) =~ \"{Workspace}\"\r\n"
    "| summarize Count = dcount(id)\r\n"
    "| project value = tostring(Count)"
)
step3_schema_items.append(params_item([
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "ExistingDcrCount",
        "type": 1,
        "query": q_existing_dcr_count,
        "crossComponentResources": ["{Subscriptions}"],
        "isHiddenWhenLocked": True,
        "queryType": 1,
        "resourceType": "microsoft.resourcegraph/resources",
    }
], "parameters - Existing DCR Count", query_type=1, resource_type="microsoft.resourcegraph/resources"))
step3_schema_items.append(query_item(
    q_selected_dcrs,
    "query ResourceGraph - ExistingDcrsForTable",
    query_type=1,
    size=1,
    title="Existing DCRs targeting this table and workspace",
    resource_type="microsoft.resourcegraph/resources",
    cross_component=["{Subscriptions}"],
    no_data_message="No existing DCR targets this table in the selected workspace.",
    grid_settings={
        "rowLimit": 100,
        "filter": True,
        "formatters": [
            {"columnMatch": "DCR resource ID", "formatter": 5, "formatOptions": {"linkTarget": "Resource"}},
            {"columnMatch": "DCE resource ID", "formatter": 5, "formatOptions": {"linkTarget": "Resource"}},
        ],
    },
))
step3_schema_items.append(text(
    "**Existing DCR detected:** `{ExistingDcrCount}` DCR(s) already target this table in the selected workspace. "
    "Review them above before creating another rule; overlapping senders can duplicate ingestion.",
    "text - step3 existing dcr warning",
    style="warning",
    cv={"parameterName": "ExistingDcrCount", "comparison": "isNotEqualTo", "value": "0"}
))

step3_schema_visibility = {"parameterName": "TableDcrReady", "comparison": "isEqualTo", "value": "true"}
step3_page_items = [text(
    "# 3 | Inspect schema and existing DCRs\n"
    "Review the proposed input mapping and confirm whether another DCR already targets **{SelectedTableName}**.",
    "text - section 3",
    style="info",
)]
for item in step3_schema_items:
    if "conditionalVisibility" not in item:
        item["conditionalVisibility"] = step3_schema_visibility
step3_page_items.extend(step3_schema_items)
step3_page_items.append(wizard_nav_item(
    "Step3 Next",
    [("Next: reveal DCR configuration below", "RevealStep4", "primary")],
    {"parameterName": "ConfigurationReady", "comparison": "isEqualTo", "value": "true"},
))
items.append(wizard_page(step3_page_items, "Inspect schema and DCRs", "RevealStep3"))

# ---------------------------------------------------------------------------
# STEP 4: Configure the DCR
# ---------------------------------------------------------------------------
step4_params = [
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "DcrName", "label": "Data Collection Rule name",
        "type": 1, "isRequired": True,
        "criteriaData": [{"criteriaContext": {"operator": "Default", "resultValType": "static", "resultVal": "dcr-{SelectedTableName}"}}],
        "typeSettings": {"paramValidationRules": [
            {"match": True, "regExp": "^[a-zA-Z0-9_-]{1,64}$", "message": "1-64 letters, numbers, underscores or hyphens"}
        ]},
    },
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "CreateNewDce",
        "label": "Data Collection Endpoint", "type": 10, "isRequired": True,
        "jsonData": "[\r\n    {\"value\":\"true\", \"label\": \"Create a new DCE\", \"selected\": true},\r\n    {\"value\":\"false\", \"label\": \"Use an existing DCE\", \"selected\": false}\r\n]",
    },
]
step4_params_newdce = [
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "NewDceName", "label": "New DCE name",
        "type": 1, "isRequired": True,
        "criteriaData": [{"criteriaContext": {"operator": "Default", "resultValType": "static", "resultVal": "dce-v1-ingestion"}}],
        "typeSettings": {"paramValidationRules": [
            {
                "match": True,
                "regExp": "^[a-zA-Z0-9](?:[a-zA-Z0-9-]{1,42}[a-zA-Z0-9])$",
                "message": "3-44 letters, numbers or hyphens; cannot start or end with a hyphen",
            }
        ]},
    },
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "NewDceDeploymentReady",
        "type": 1,
        "query": (
            "let validDcrName = \"{DcrName}\" matches regex @'^[a-zA-Z0-9_-]{1,64}$';\r\n"
            "let validDceName = \"{NewDceName}\" matches regex @'^[a-zA-Z0-9](?:[a-zA-Z0-9-]{1,42}[a-zA-Z0-9])$';\r\n"
            "print value = tolower(tostring("
            "\"{ConfigurationReady}\" == \"true\" and validDcrName and validDceName))"
        ),
        "crossComponentResources": ["{Workspace}"],
        "isHiddenWhenLocked": True,
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
    },
]
step4_params_existingdce = [
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "ExistingDce", "label": "Existing DCE",
        "type": 5, "isRequired": False,
        "query": (
            "resources\r\n| where type =~ \"microsoft.insights/datacollectionendpoints\"\r\n"
            "| where id startswith \"{ResourceGroupId}\"\r\n| project value = id, label = name"
        ),
        "crossComponentResources": ["{Subscriptions}"],
        "typeSettings": {"additionalResourceOptions": [], "showDefault": False},
        "queryType": 1, "resourceType": "microsoft.resourcegraph/resources",
    },
    {
        "id": g(),
        "version": "KqlParameterItem/1.0",
        "name": "ExistingDceDeploymentReady",
        "type": 1,
        "query": (
            "let validDcrName = \"{DcrName}\" matches regex @'^[a-zA-Z0-9_-]{1,64}$';\r\n"
            "print value = tolower(tostring("
            "\"{ConfigurationReady}\" == \"true\" and validDcrName and isnotempty(\"{ExistingDce}\")))"
        ),
        "crossComponentResources": ["{Workspace}"],
        "isHiddenWhenLocked": True,
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
    },
]
step4_state_params = [
    {
        "id": g(), "version": "KqlParameterItem/1.0", "name": "DceMode", "type": 1,
        "query": "print value = \"{CreateNewDce}\"",
        "crossComponentResources": ["{Workspace}"],
        "isHiddenWhenLocked": True,
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
    },
]
step4_config_items = [
    text(
        "## 4. Configure the Data Collection Rule\n"
        "The DCR is created in the **same resource group and region as the workspace** "
        "(`{ResourceGroupId}`, `{WorkspaceLocation}`), per Azure Monitor recommended practice. "
        "Choose a name, and either create a new Data Collection Endpoint (DCE) or reuse one that already "
        "exists in the resource group.",
        "text - step4 config intro"
    ),
    params_item(step4_params, "parameters - Step4"),
    params_item(step4_state_params, "parameters - WorkflowState"),
    params_item(
        step4_params_newdce, "parameters - Step4 NewDce",
        query_type=0
    ) | {"conditionalVisibility": {"parameterName": "DceMode", "comparison": "isEqualTo", "value": "true"}},
    params_item(
        step4_params_existingdce, "parameters - Step4 ExistingDce",
        query_type=0
    ) | {"conditionalVisibility": {"parameterName": "DceMode", "comparison": "isEqualTo", "value": "false"}},
    text(
        "**New DCE** will be created: `{NewDceName}` in `{WorkspaceLocation}`.",
        "text - step3 newdce note",
        cv={"parameterName": "DceMode", "comparison": "isEqualTo", "value": "true"}
    ),
    text(
        "**Existing DCE** selected: `{ExistingDce:label}`.",
        "text - step3 existingdce note",
        cv={"parameterName": "DceMode", "comparison": "isEqualTo", "value": "false"}
    ),
    query_item(
        (
            "let cols = dynamic({InputColumnsJson});\r\n"
            "print col = cols\r\n| mv-expand col\r\n"
            "| project ['Input stream column'] = tostring(col.name), ['DCR type'] = tostring(col.type)"
        ),
        "query LogAnalytics - InputStreamPreview", query_type=0, size=1,
        title="Preview: DCR input stream columns",
        resource_type="microsoft.operationalinsights/workspaces", cross_component=["{Workspace}"],
        grid_settings={"rowLimit": 500},
    ),
    text(
        "**Transformation KQL** that will run in the DCR. In clean-name mode it restores the table's existing "
        "suffixed names; in compatibility mode it remains `source` because input names already match:\n"
        "```kusto\n{TransformKqlText}\n```",
        "text - step3 transform preview"
    ),
]
step4_config_visibility = {"parameterName": "ConfigurationReady", "comparison": "isEqualTo", "value": "true"}
step4_page_items = [text(
    "# 4 | Configure the DCR\n"
    "The input schema is ready. Configure the DCR and choose whether to create or reuse a Data Collection Endpoint.",
    "text - section 4",
    style="success",
)]
for item in step4_config_items:
    if item["name"] != "parameters - WorkflowState" and "conditionalVisibility" not in item:
        item["conditionalVisibility"] = step4_config_visibility
step4_page_items.extend(step4_config_items)
step4_page_items.append(mode_group([
    wizard_nav_item(
        "Step4 Next NewDce",
        [("Next: reveal review and deployment below", "RevealStep5", "primary")],
        {"parameterName": "NewDceDeploymentReady", "comparison": "isEqualTo", "value": "true"},
    ),
    text(
        "Complete a valid **DCR name** and **new DCE name** to continue.",
        "text - step4 newdce incomplete",
        style="warning",
        cv={"parameterName": "NewDceDeploymentReady", "comparison": "isEqualTo", "value": "false"},
    ),
], "Step4 NewDce Actions", "true"))
step4_page_items.append(mode_group([
    wizard_nav_item(
        "Step4 Next ExistingDce",
        [("Next: reveal review and deployment below", "RevealStep5", "primary")],
        {"parameterName": "ExistingDceDeploymentReady", "comparison": "isEqualTo", "value": "true"},
    ),
    text(
        "Complete a valid **DCR name** and select an **existing DCE** to continue.",
        "text - step4 existingdce incomplete",
        style="warning",
        cv={"parameterName": "ExistingDceDeploymentReady", "comparison": "isEqualTo", "value": "false"},
    ),
], "Step4 ExistingDce Actions", "false"))
items.append(wizard_page(step4_page_items, "Configure DCR", "RevealStep4"))

# ---------------------------------------------------------------------------
# STEP 5: Review and deploy
# ---------------------------------------------------------------------------
template_uri = (
    "https://raw.githubusercontent.com/TheAlistairRoss/The-Cloud-Brain-Dump/main/"
    "Toolshed/Log%20Analytics%20V1%20Table%20Workbook/azuredeploy.json"
)

deployment_parameters_common = [
    {"name": "location", "source": "parameter", "value": "WorkspaceLocation", "kind": "stringValue"},
    {"name": "createNewDce", "source": "parameter", "value": "CreateNewDce", "kind": "boolValue"},
    {"name": "dcrName", "source": "parameter", "value": "DcrName", "kind": "stringValue"},
    {"name": "tableName", "source": "parameter", "value": "SelectedTableName", "kind": "stringValue"},
    {"name": "workspaceResourceId", "source": "parameter", "value": "Workspace", "kind": "stringValue"},
    {"name": "inputColumns", "source": "parameter", "value": "InputColumnsJson", "kind": "arrayValue"},
    {"name": "transformKql", "source": "parameter", "value": "TransformKqlText", "kind": "stringValue"},
]
deployment_parameters_new_dce = deployment_parameters_common + [
    {"name": "newDceName", "source": "parameter", "value": "NewDceName", "kind": "stringValue"},
    {"name": "existingDceResourceId", "source": "static", "value": "", "kind": "stringValue"},
]
deployment_parameters_existing_dce = deployment_parameters_common + [
    {"name": "newDceName", "source": "static", "value": "unused-dce", "kind": "stringValue"},
    {"name": "existingDceResourceId", "source": "parameter", "value": "ExistingDce", "kind": "stringValue"},
]

step5_items = [
    text(
        "## 5. Review & deploy\n"
        "Use **Review and Deploy Data Collection Rule** to open Azure's native ARM deployment experience. Select "
        "**View template** to inspect the hosted template and substituted parameters before deploying the Data "
        "Collection Rule and, if selected, a new Data Collection Endpoint.",
        "text - step5 intro"
    ),
    mode_group([
        arm_template_item(
            label="Review and Deploy Data Collection Rule",
            template_uri=template_uri,
            template_parameters=deployment_parameters_new_dce,
            title="Deploy Data Collection Rule and Endpoint",
            description=(
                "The template deploys **{DcrName}** and, when requested, **{NewDceName}** into `{ResourceGroupId}`. "
                "Use **View template** to inspect the resources and parameter values before deployment. No changes are "
                "made to the destination schema for `{SelectedTableName}`."
            ),
            name="DeployDcrNewDce",
        ) | {"conditionalVisibility": {
            "parameterName": "NewDceDeploymentReady", "comparison": "isEqualTo", "value": "true"
        }},
    ], "Step5 NewDce Deployment", "true"),
    mode_group([
        arm_template_item(
            label="Review and Deploy Data Collection Rule",
            template_uri=template_uri,
            template_parameters=deployment_parameters_existing_dce,
            title="Deploy Data Collection Rule and Endpoint",
            description=(
                "The template deploys **{DcrName}** using the selected existing DCE into `{ResourceGroupId}`. "
                "Use **View template** to inspect the resources and parameter values before deployment. No changes are "
                "made to the destination schema for `{SelectedTableName}`."
            ),
            name="DeployDcrExistingDce",
        ) | {"conditionalVisibility": {
            "parameterName": "ExistingDceDeploymentReady", "comparison": "isEqualTo", "value": "true"
        }},
    ], "Step5 ExistingDce Deployment", "false"),
    text(
        "**Note:** You need `Microsoft.Insights/dataCollectionRules/write` (and, if creating a new DCE, "
        "`Microsoft.Insights/dataCollectionEndpoints/write`) permission on the resource group to deploy - "
        "for example via the **Monitoring Contributor** built-in role. After deployment, update your ingestion "
        "client to call the [Logs ingestion API](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-ingestion-api-overview) "
        "against this DCR instead of the legacy HTTP Data Collector API.",
        "text - step5 permissions note", style="info",
        cv={"parameterName": "ConfigurationReady", "comparison": "isEqualTo", "value": "true"}
    ),
]
step5_visibility = {"parameterName": "ConfigurationReady", "comparison": "isEqualTo", "value": "true"}
step5_page_items = [text(
    "# 5 | Review and deploy\n"
    "Open the native ARM deployment to review the hosted template before deploying **{DcrName}**.",
    "text - section 5",
    style="success",
)]
for item in step5_items:
    if "conditionalVisibility" not in item:
        item["conditionalVisibility"] = step5_visibility
step5_page_items.extend(step5_items)
items.append(wizard_page(step5_page_items, "Review and deploy", "RevealStep5"))

workbook = {
    "version": "Notebook/1.0",
    "items": items,
    "styleSettings": {},
    "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json",
}

with open("LogAnalyticsV1TableWorkbook.json", "w", encoding="utf-8") as f:
    json.dump(workbook, f, indent=2)

print("Wrote LogAnalyticsV1TableWorkbook.json")
