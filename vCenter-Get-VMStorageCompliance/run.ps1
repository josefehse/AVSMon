# Input bindings are passed in via param block.
param($Timer)

# Environment Variables
$LogType="VMStorageCompliance"
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

# Initialize an array to hold the results
$result = @()

# Get all clusters in vCenter
$clusters = Get-Cluster

# Loop through each cluster and check storage policy compliance for each VM
foreach ($cluster in $clusters) {
    Write-Output "Checking storage policy compliance for cluster $($cluster.Name):"
    
    # Get VMs in the current cluster
    $vms = Get-VM -Location $cluster

    foreach ($vm in $vms) {
        # Get storage policy compliance status
        $spbmConfig = Get-SpbmEntityConfiguration $vm
        foreach ($policy in $spbmConfig) {
            $complianceStatus = if ($policy.ComplianceStatus -eq "compliant") {"Compliant"} else {"Non-Compliant"}
            $result += [PSCustomObject]@{
                VMName = $vm.Name
                StoragePolicy = $policy.StoragePolicy.Name
                ComplianceStatus = $complianceStatus
            }
        }
    }
}

# Convert the result to JSON
$jsonArray = $result | ConvertTo-Json -Depth 100

# Print the output
Write-Output "JSON Array Output:"
Write-Output $jsonArray

# Print the output
Write-Output "JSON Array Output:"
Write-Output $jsonArray

Send-LogToLogAnalytics -CustomerId $CustomerId `
                         -SharedKey $sharedKey `
                         -Log $jsonArray `
                         -LogType "VMStorageCompliance"

# Disconnect from vCenter Server
Disconnect-VIServer -Confirm:$false



