# Sentinel Threat Intelligence PowerShell Module

Using the [generally avaliable API's](https://learn.microsoft.com/en-us/rest/api/securityinsights/threat-intelligence-indicator?view=rest-securityinsights-2024-03-01), I have built a few PowerShell functions to get and delete threat intellingence indicators from a Sentinel workspace. The leverage the Azure Az.Accounts Module to get the token and invoke the request using Invoke-AzRestMethod.

Ensure the authentication has occurred using Connect-AzAccount prior to running the functions.

## Functions

|Function|Description|
|--|--|
|[Get-ThreatIndicatorsQuery](./Docs/Get-ThreatIndicatorsQuery.md)|This function retrieves threat indicators based on the specified on filters.|
|[Get-ThreatIndicatorsMetrics](./Docs/Get-ThreatIndicatorsMetrics.md)|This function retrives the threat indicator metrics from the specified workspace.|
|[Remove-ThreatIndicator](./Docs/Remove-ThreatIndicator.md)|This function removes a single threat indicator from a specified workspace|
|[Remove-ThreatIndicatorsQuery](./Docs/Remove-ThreatIndicatorsQuery.md)|This function retrieves and deletes threat indicators based on the specified on filters.|


## Release
|Version|Date|Download|
|--|--|--|
|[1.0.0](./Build/1.0.0)| 05/08/2024|[Download](./Build/1.0.0/SentinelThreatIntelligence.zip| 

## Issues
The function ```Remove-ThreatIndicator``` and ```Remove-ThreatIndicatorsQuery``` relies on the [Threat Intelligence Indicator - Delete](https://learn.microsoft.com/en-us/rest/api/securityinsights/threat-intelligence-indicator/delete?view=rest-securityinsights-2024-03-01&tabs=HTTP) API which is limited to 1 request at a time. Based on the new [throttling algorithm](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/request-limits-and-throttling#migrating-to-regional-throttling-and-token-bucket-algorithm) this should be able to perform 10 deletes per second without being throttled.

Improvements need to be made to this script to increase performance as the script currently runs in serial and current testing has the deletion at the rate of 1 event per 1.61 seconds
