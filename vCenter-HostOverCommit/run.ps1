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
 “avsvCenterAdmin:$avsvCenterAdmin”
# “avsNSXTAdmin:$avsNSXTAdmin”
 “avsvCenterAdminPassword:$avsvCenterAdminPassword”
# “avsNSXTAdminPassword:$avsNSXTAdminPassword”

# The following are used to verify network connectivity to the vCenter, HCX and NSXT 
# $vCenter=Test-connection $vCenterURL.trim("https://") -tcpport 443
# $VCntr=Test-connection $vCenterURL.trim("https://") -tcpport 443
# $HCX=Test-connection $HCXURL.trim("https://") -tcpport 443
# $NSXT=Test-connection $NSXTURL.trim("https://") -tcpport 443

# "VC Network connection valid: $vCntr"
# "HC Network connection valid: $HCX"
# "NSX Network connection valid: $NSXT"

# disables certificate checks (because of self-signed certificates.)
# disables certificate checks (because of self-signed certificates.)
if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
{
$certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
 }
# "Finished"

# Bypass certificate requirement
[ServerCertificateValidationCallback]::Ignore()
# Set TLS Version to 1.2
   #"Before" 
   #[System.Net.ServicePointManager]::SecurityProtocol
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
   #[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} ;
   # "After"
   # [System.Net.ServicePointManager]::SecurityProtocol

# Create Credential for vCenter Automatically (DISABLED FOR THIS VERSION THAT IS QUERYING NSXT)
# ---------------------------------------------------------------------------------------------
 $password = ConvertTo-SecureString "$avsvCenterAdminPassword" -AsPlainText -Force
 $credential = New-Object System.Management.Automation.PSCredential($avsvCenterAdmin, $password)

# Create Credential for HCX Automatically (DISABLED FOR THIS VERSION THAT IS QUERYING NSXT)
# ---------------------------------------------------------------------------------------------
# $password = ConvertTo-SecureString $avsvCenterAdminPassword -AsPlainText -Force
# $credential = New-Object System.Management.Automation.PSCredential($avsvCenterAdmin, $password)

# Create Credential Automatically for NSXT (ENABLED)
# ---------------------------------------------------------------------------------------------
# $password = ConvertTo-SecureString $avsNSXTAdminPassword -AsPlainText -Force
# $credential = New-Object System.Management.Automation.PSCredential($avsNSXTAdmin, $password)

$base64Creds = [Convert]::toBase64String([System.Text.Encoding]::UTF8.GetBytes("$($credential.username):$($credential.GetNetworkCredential().password)"))
$header = @{Authorization = "Basic $base64Creds"}

# This line disables the requirement to check the certificate for the connect-viserer powercli command
 Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
 # Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false.

# END of the variable definitions and authentication process - this is repeatable for all powershell and URI queries.
# ___________________________________________________________________________________________________________________

$vCenter = connect-viserver $vCenterURL.trim('https://') -protocol https -user $avsvCenterAdmin -password $avsvCenterAdminPassword -force
#"The list of hosts from : $vCenter"
$vCenterhosts=get-vmhost -location sddc-datacenter | Where-Object { $_.ConnectionState -ne "Maintenance" }
#$vCenterhosts.id
"The valud of vCenterhosts: $vCenterhosts"
"___________________________________________"
"Found $($vCenterhosts.count) host server objects."

# Initialize an empty array to store the results
$resultArray = @()

ForEach ($esx in $vCenterhosts) {
    $vCPU = Get-VM -Location $esx | Measure-Object -Property NumCpu -Sum | select -ExpandProperty Sum

    $result = $esx | Select-Object -Property @{
        N = 'Name'; E = {$_.Name}
    }, @{
        N = 'pCPU cores available'; E = {$_.NumCpu}
    }, @{
        N = 'vCPU assigned to VMs'; E = {$vCPU}
    }, @{
        N = 'Ratio'; E = {[math]::Round($vCPU/$_.NumCpu,1)}
    }, @{
        N = 'CPU Overcommit (%)'; E = {[Math]::Round(100*(($vCPU - $_.NumCpu) / $_.NumCpu), 1)}
    }

    # Add the result to the array
    "This is the result: $result"
    $resultArray += $result
}

# Check output is as expected in the CLI
# $resultArray

"--------------------"
$ResultData = $resultArray | ConvertTo-Json -Depth 3
$ResultData

# Post the data to Log Analytics
#$body = $resultArray | ConvertTo-Json -Depth 3

Send-LogToLogAnalytics -CustomerId $CustomerId `
                         -SharedKey $sharedKey `
                         -Log $ResultData `
                         -LogType $LogType