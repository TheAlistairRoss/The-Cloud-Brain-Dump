# Analytics to Basic Log via KQL Transformation Template Generator (Working Title!)

This workbook has been designed with the aim to reduce costs incurred by customers when using Microsoft Sentinel and Azure Monitor Logs.

The concept is that not all data has the same value to teams, and therefore you may want to handle and use the data differently. For examples some security data, like sign in logs, have a high value, whereas a subset of that data may be considered low value to that organisation. 

By default all data is ingested into Microsoft Sentinel as Analytics logs, this allows you to perform queries, run detections and build visualisations with the data. You can create custom tables (and change a select built in tables) to basic logs. Basic logs allow you to ingest and retain the data at a much lower cost, but with limited functionality. To find out more, read the documentation found [here](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/basic-logs-configure?tabs=portal-1#compare-the-basic-and-analytics-log-data-plans).

The output of this workbook is an ARM template, it does not actually deploy anything unless you press the deploy button. The workflow is as follows.

1. You select an existing table in your workspace.
2. It displays the schema of the table, this will be used for you new table. (You change this in the ARM template).
3. It creates a new table, set as basic logs. You can change the name if the default is not right for your requirements.
4. You create a new transformation for both the original and new table.
5. Incoming data to the original table will be duplicated and sent to each table, passing through the transformation filters you have created.

![GIF image showing logs going to analytics and basic logs table.](/Toolshed/Sentinel%20Toolbox/Analytics%20to%20Basic%20Log%20via%20KQL%20Transformation%20Template%20Generator/Resources/LogSplittingViaDCR.gif)

The aim is that the lower value data can be filtered out from the analytics tables, but still kept and ingested into the basic logs table, reducing overall costs to the organisation.