# Input bindings are passed in via param block.
param($Timer)

# Environment Variables
$LogType="AVSLogs"
$KeyVaultName=$env:KeyVaultName
$HCXURL = $env:HCXURL
$vCenterURL = $env:vCenterURL
$NSXTURL = $env:NSXTURL 

# KeyVault Secrets
$SharedKey=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "sharedkey" -asplaintext
$avsvCenterAdmin=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsvCenterAdmin" -asplaintext
$avsNSXTAdmin=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsNSXTAdmin" -asplaintext
$avsvCenterAdminPassword=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsvCenterAdminPassword" -asplaintext
# $avsNSXTAdminPassword=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsNSXTAdminPassword" -asplaintext
$avsNSXTAdminPassword=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "5f92v)U!1xxP" -asplaintext

#Note this example uses the cloudadmin@vsphere.local account to authenticate with both vCenter and HCX
#Note this example uses cloudadmin account to authenticate with NSXT

# The following are used for checking that environment variables and keyvault secrets are being retrieved.
#
 "vCenterURL: $vCenterURL"
 "HCXURL: $HCXURL"
 "NSXTURL: $NSXTURL"
# "KeyVault: $KeyVaultName"
# "LogAnalyticsKey:$SharedKey”
# “avsvCenterAdmin:$avsvCenterAdmin”
# “avsNSXTAdmin:$avsNSXTAdmin”
# “avsvCenterAdminPassword:$avsvCenterAdminPassword”
“avsNSXTAdminPassword:$avsNSXTAdminPassword”

# The following are used to verify network connectivity to the vCenter, HCX and NSXT 
 $vCenter=Test-connection $vCenterURL.trim("https://") -tcpport 443
 $VCntr=Test-connection $vCenterURL.trim("https://") -tcpport 443
 $HCX=Test-connection $HCXURL.trim("https://") -tcpport 443
 $NSXT=Test-connection $NSXTURL.trim("https://") -tcpport 443

 "VC Network connection valid: $vCntr"
 "HC Network connection valid: $HCX"
 "NSX Network connection valid: $NSXT"

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

# Create Credential Automatically
$password = ConvertTo-SecureString $avsvCenterAdminPassword -AsPlainText -Force
# $password = ConvertTo-SecureString $password -AsSecureString #-Force
$credential = New-Object System.Management.Automation.PSCredential($avsvCenterAdmin, $password)

# Create Credential Automatically (vCenter & HCX in this example)
# $password = ConvertTo-SecureString $avsvCenterAdminPassword -AsPlainText -Force
# $credential = New-Object System.Management.Automation.PSCredential($avsvCenterAdmin, $password)

# Create Credential Automatically (NSXT)
$password = ConvertTo-SecureString $avsNSXTAdminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($avsNSXTAdmin, $password)

$base64Creds = [Convert]::toBase64String([System.Text.Encoding]::UTF8.GetBytes("$($credential.username):$($credential.GetNetworkCredential().password)"))
$header = @{Authorization = "Basic $base64Creds"}

# END of the variable definitions and authentication process - this is repeatable for all powershell and URI queries.
# ___________________________________________________________________________________________________________________

# This section queries the NSX-T firewall policy rules.  All policies, all rules, if the rule is enabled and if logging is enabled.
#"Check header name and value:"
# $header
#$"HEADER: $NSXTURL/policy/api/v1/infra/domains/default/security-policies"

# invoke-webrequest -uri "$url/policy/api/v1/infra/domains/default/security-policies/WebServers/rules" -headers $header 

# Old Method: $output = invoke-webrequest -uri "$url/policy/api/v1/infra/domains/default/security-policies/WebServers/rules" -headers $header 
$output = " "
$output = (Invoke-RestMethod -uri "$NSXTurl/policy/api/v1/infra/domains/default/security-policies" -headers $header -SkipCertificateCheck).results
$output
"Output list"
$policies = $output.id  #this is an array with four policies
"Found $($policies.count) policy objects."

[PSCustomObject] $PolicyList = New-Object System.Collections.ArrayList

foreach ($policy in $policies){
    $output =" "
    $output = (Invoke-RestMethod -uri "$NSXTurl/policy/api/v1/infra/domains/default/security-policies/$policy/rules" -headers $header -SkipCertificateCheck).results 

    $enabledRules = $output | ?{$_.logged -eq "True"} # -and $_.disabled -eq "False"}   #This checks to see if logging is enabled for the rule and if the rule is disabled
    # $disabledRules = $output.results | ?{$_.logged -eq "False"}     #This checks to see if logging is disenabled for the rule
    if ($enabledRules.Count -gt 0) {
        "Found $($enabledRules.Count) rules in $policy policy."
        foreach ($rule in $enabledRules) {
            $RuleObject = [PSCustomObject]@{ 
                PolicyName=$policy
                RuleId = $rule.id
                RuleName = $rule.display_name
                LogEnabled  = $rule.logged
                Action = $rule.action
            }
            $PolicyList.add($RuleObject)
            $RuleObject
            "XXXXXXXXXXXXXXXXXXXXXX"
        }
    }
    else {
        # When it returns no more rules in the policy
        #"$policy : N/A"
        # "TTTTTTTTTTTTTTTTTTTT"
    }
    
    # Add another for each for each rule and check for each rule if Logged True/False
    #$enabledRules.id
}
