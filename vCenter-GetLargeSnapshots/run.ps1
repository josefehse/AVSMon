# Input bindings are passed in via param block.
param($Timer)

# Environment Variables
$LogType="VMsLargeSnapshots"
$KeyVaultName=$env:KeyVaultName
$HCXURL = $env:HCXURL
$vCenterURL = $env:vCenterURL
$NSXTURL = $env:NSXTURL
$CustomerID = $env:LAW_WorkSpace_ID

# KeyVault Secrets
$SharedKey=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsLAWKey" -asplaintext
$avsvCenterAdmin=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsvCenterAdmin" -asplaintext
$avsNSXTAdmin=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsNSXTAdmin" -asplaintext
$avsvCenterAdminPassword=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "AVSSDDCvCentrerAdminAccountPassword" -asplaintext
$avsNSXTAdminPassword=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsNSXTAdminPassword" -asplaintext
$avsLAWSecret=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsLAWKey" -asplaintext

#Note this example uses the cloudadmin@vsphere.local account to authenticate with both vCenter and HCX
#Note this example uses cloudadmin account to authenticate with NSXT

# The following are used for checking that environment variables and keyvault secrets are being retrieved.
# "LAWSharedKey: $sharedKey"
# "CustomerID: $CustomerID"
 "vCenterURL: $vCenterURL"
# "HCXURL: $HCXURL"
# "NSXTURL: $NSXTURL"
# "KeyVault: $KeyVaultName"
# "LogAnalyticsKey:$SharedKey”
 “avsvCenterAdmin:$avsvCenterAdmin”
# “avsNSXTAdmin:$avsNSXTAdmin”
 “avsvCenterAdminPassword:$avsvCenterAdminPassword”
# “avsNSXTAdminPassword:$avsNSXTAdminPassword”
 Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

# END of the variable definitions and authentication process - this is repeatable for all powershell and URI queries.
# ___________________________________________________________________________________________________________________

$vCenter = Connect-viserver $vCenterURL.trim('https://') -protocol https -user $avsvCenterAdmin -password $avsvCenterAdminPassword

# Get VM snapshot data
$vms = Get-VM | Get-Snapshot | Where-Object { $_.SizeMB -gt 2048 } | Select-Object VM, Name, SizeMB, Created

# Convert the result to JSON
$jsonArray = $vms | ConvertTo-Json -Depth 100

# Print the output
Write-Output "JSON Array Output:"
Write-Output $jsonArray

Send-LogToLogAnalytics -CustomerId $CustomerId `
                         -SharedKey $sharedKey `
                         -Log $jsonArray `
                         -LogType "VMsLargeSnapshots"

# Disconnect from vCenter Server
Disconnect-VIServer -Confirm:$false


