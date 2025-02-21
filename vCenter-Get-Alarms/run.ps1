# Input bindings are passed in via param block.
param($Timer)

# Environment Variables
$LogTable="TempTable"
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
# “avsvCenterAdminPassword:$avsvCenterAdminPassword”
# “avsNSXTAdminPassword:$avsNSXTAdminPassword”
 Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

# END of the variable definitions and authentication process - this is repeatable for all powershell and URI queries.
# ___________________________________________________________________________________________________________________

$vCenter = Connect-viserver $vCenterURL.trim('https://') -protocol https -user $avsvCenterAdmin -password $avsvCenterAdminPassword

function Get-TriggeredAlarm {

    [CmdletBinding()]
    param(
        [string]$VM,
        [string]$VMHost,
        [string]$Datacenter
    )
    BEGIN {
        switch ($PSBoundParameters.Keys) {
            'VM' {$entity = Get-VM -Name $VM -ErrorAction SilentlyContinue}
            'VMHost' {$entity = Get-VMHost -Name $VMHost -ErrorAction SilentlyContinue}
            'Datacenter' {$entity = Get-Datacenter -Name $Datacenter -ErrorAction SilentlyContinue}
            default {$entity = $null}
        }

        if ($null -eq $entity) {
            Write-Warning "No vSphere object found."
            break
        }
    }
    PROCESS {
        if ($entity.ExtensionData.TriggeredAlarmState -ne "") {
            $alarmOutput = @()
            foreach ($alarm in $entity.ExtensionData.TriggeredAlarmState) {
                $tempObj = "" | Select-Object -Property Entity, Alarm, AlarmStatus
                $tempObj.Entity = Get-View $alarm.Entity | Select-Object -ExpandProperty Name
                $tempObj.Alarm = Get-View $alarm.Alarm | Select-Object -ExpandProperty Info | Select-Object -ExpandProperty Name
                $tempObj.AlarmStatus = $alarm.OverallStatus
#                $tempObj.AlarmMoRef = $alarm.Alarm
#                $tempObj.EntityMoRef = $alarm.Entity
                $alarmOutput += $tempObj
            }
            $alarmOutput | Format-Table -AutoSize
        }
    }
    END {
        if ($entity -ne $null -and $entity.ExtensionData.TriggeredAlarmState -ne "") {
             #$jsonArray = $alarmOutput  | ConvertTo-Json -Depth 100
             #"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
             #Write-Output "JSON Array Output #1:"
             #Write-Output $jsonArray 
             #"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
            return $alarmOutput | ConvertTo-Json -Depth 100
        }
    }
}

$result = Get-TriggeredAlarm -Datacenter "sddc-datacenter" 

# Print the output
"_____________________________________________"
Write-Output "Result Output #2:"
Write-Output $result 
"_____________________________________________"


Send-LogToLogAnalytics -CustomerId $CustomerId `
                         -SharedKey $sharedKey `
                         -Log $result `
                         -LogType "NewLogTable"

# Disconnect from vCenter Server

Disconnect-VIServer -Confirm:$false
