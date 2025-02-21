# Input bindings are passed in via param block.
param($Timer)

# Environment Variables
$LogType="avsvCenterHostOverCommit"
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
# "vCenterURL: $vCenterURL"
# "HCXURL: $HCXURL"
# "NSXTURL: $NSXTURL"
# "KeyVault: $KeyVaultName"
# "LogAnalyticsKey:$SharedKey”
# “avsvCenterAdmin:$avsvCenterAdmin”
# “avsNSXTAdmin:$avsNSXTAdmin”
# “avsvCenterAdminPassword:$avsvCenterAdminPassword”
# “avsNSXTAdminPassword:$avsNSXTAdminPassword”

# END of the variable definitions and authentication process - this is repeatable for all powershell and URI queries.
# ___________________________________________________________________________________________________________________

$vCenter = Connect-viserver $vCenterURL.trim('https://') -protocol https -user $avsvCenterAdmin -password $avsvCenterAdminPassword

$vmsWithTools = Get-VM | Where-Object {
    $_.ExtensionData.Guest.ToolsStatus -ne 'toolsNotInstalled' 
}

$vmsWithoutTools = Get-VM | Where-Object {
    $_.ExtensionData.Guest.ToolsStatus -eq 'toolsNotInstalled' -or
    $_.ExtensionData.Guest.ToolsStatus -eq $null
}

$resultArray = @()

ForEach ($esx in $vmsWithoutTools) {
    $vCPU = Get-VM 

    $result = $esx | Select-Object -Property @{
        N = 'Name'; E = {$_.Name}
    }

    # Add the result to the array
    $resultArray += $result
}

$ResultData = $resultArray | ConvertTo-Json -Depth 100
$ResultData

$LogTable = "VMsWithoutTools"

Send-LogToLogAnalytics -CustomerId $CustomerId `
                         -SharedKey $sharedKey `
                         -Log $ResultData `
                         -LogType $LogTable
