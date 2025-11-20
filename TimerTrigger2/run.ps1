# Input bindings are passed in via param block.
param($Timer)


# HCX Queries
    # Is the site pair up
    $result= "Connect-HCXServer -Server <HCXServer> -User <username> -Password <password>; Get-HCXSitePairing | Select-Object SourceSite, DestinationSite, Status"
    $pairup = concat result.souresite, result.destingsite
    write  $pairup to Loganalyics l
    # Is the service mesh healthy
    " Connect-HCXServer -Server <HCXServer> -User <username> -Password <password>; Get-HCXServiceMesh | Select-Object Name, HealthStatus"
    # Query the alerts ?
    "Connect-HCXServer -Server <HCXServer> -User <username> -Password <password>; Get-HCXAlert | Select-Object Name, Severity, Status, Description"


# vCEnter Queries

    # vCenter Alerts
    "Connect-VIServer -Server <vCenterServer> -User <username> -Password <password>; Get-AlarmAction | Where-Object {$_.State -eq "red" -or $_.State -eq "yellow"} | Select-Object Name, Entity, State, Time"

    # Is the diagnostic setting turned on - check to see if syslog out is configured ( I think it is by default when we turn on diagnostics)
    "Check the Azure API for AVS"

    # Get VM's that don't have VM tools
    "Connect-VIServer -Server <vCenterServer> -User <username> -Password <password>; Get-VM | Where-Object {$_.ExtensionData.Guest.ToolsStatus -eq "toolsNotInstalled"} | Select-Object Name"

    # Do VMs have existing snapshots - or large snapshots over 2GB in size, this should not happen. These should be cleaned up
    "Get-VM | Get-Snapshot | Where-Object { $_.SizeGB -gt 2 } | Select-Object VM, Name, SizeGB, Created"

    # Check SYSLOGS are enabled
    "Connect-VIServer -Server <vCenterServer> -User <username> -Password <password>; Get-AdvancedSetting -Entity (Get-VMHost) -Name Syslog.global.logHost | Select-Object Entity, Name, Value"
    "Get-VMHost | Get-AdvancedSetting -Name Syslog.global.logHost | Select-Object Entity, Name, Value"

    # VM Machine performance queries
        #Ballooning 
        "Get-View -ViewType VirtualMachine | Where-Object {$_.Summary.QuickStats.BalloonedMemory -ne 0} | Select-Object Name, @{Name="BalloonedMemoryMB";Expression={$_.Summary.QuickStats.BalloonedMemory}}"

        #Swapping
        "Get-View -ViewType VirtualMachine | Where-Object {$_.Summary.QuickStats.SwappedMemory -ne 0} | Select-Object Name, @{Name="SwappedMemoryMB";Expression={$_.Summary.QuickStats.SwappedMemory}}"

        #Status of the VM - any alerts (powershell)
     "Get-View -ViewType VirtualMachine | Where-Object {$_.TriggeredAlarmState} | Select-Object Name, @{Name="TriggeredAlarms";Expression={$_.TriggeredAlarmState | ForEach-Object {($_.Alarm | Get-View).Info.Name}}"

    #Heartbeat - VM is locked up 
    "Get-View -ViewType VirtualMachine | Where-Object {$_.GuestHeartbeatStatus -eq "gray"} | Select-Object Name, @{Name="HeartbeatStatus";Expression={$_.GuestHeartbeatStatus}}"

    #Storeage Queries


    #Available services queries

#NSX-T Queries
    # NSX-T Alerts



# Combined Networks - NSXT, HCX and vCenter  (or any two of the three)


#C