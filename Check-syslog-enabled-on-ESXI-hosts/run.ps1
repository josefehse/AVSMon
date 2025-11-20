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

$vCenter = Connect-viserver $vCenterURL.disdis -protocol https -user $avsvCenterAdmin -password $avsvCenterAdminPassword

$vCenter

# Set up array to capture output
$resultArray = @()

# Get all ESXi hosts
$vmHosts = Get-VMHost
#$vmhosts 
#"TTTTTTTTTTTTTTTTTT"

# Loop through each host and check Syslog server configuration
foreach ($vmHost in $vmHosts) {
    $syslogServers = Get-VMHostSysLogServer -VMHost $vmHost
    $syslogServers
    
    if ($syslogServers) {
        #"Syslog is enabled for $($vmHost.Name). Syslog server(s):"
        foreach ($server in $syslogServers) {
            $result = $server | Select-Object -Property @{
            N = 'Name'; E = {($vmHost.Name).substring(0,13)}
          }, @{ 
            N = 'Enabled'; E = {"Enabled"}
          } 
          "-------------"
            $_.Name
          "-------------"
        #$resultArray += $($vmHost.Name).substring(0,13)
        $resultArray += $result
        }
    } else {
        #Troubleshooting "Syslog is not configured for $($vmHost.Name)."
        $result = $vmHost.nameI($vmHost.Name) | Select-Object -Property @{
            N = 'Name'; E = {($vmHost.Name).substring(0,13)}
          }, @{ 
            N = 'Enabled'; E = {"Not Enabled"}
          } 
        #$resultArray += $($vmHost.Name).substring(0,13)
        $resultArray += $result
    }
}

$resultArray
$ResultData = $resultArray | ConvertTo-JSON -Depth 100

$ResultData

$LogTable = "VMSyslogStatus"

Send-LogToLogAnalytics -CustomerId $CustomerId `
                         -SharedKey $sharedKey `
                         -Log $ResultData `
                         -LogType $LogTable
