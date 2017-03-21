<#
.SYNOPSIS
This is a Powershell to TurnOff VDI's or XenApp Servers without Users.

.DESCRIPTION
The script need the parameter DeliveryGroupName. 
This script must run on a desktop broker. 


.EXAMPLE
.\TurnOffwithoutUser-DependingDelvieryGroup.ps1 AdminVDI-dedicated-persistent

#>
param([string]$dg=$(throw "DeliveryGroup parameter is required"))
#==============================================================================================
# Created on: 03.2017 Version: 0.2
# Created by: Sacha Thomet
# File name: TurnOffwithoutUser-DependingDelvieryGroup.ps1
#
# Description:  
#
#
# Prerequisite: None, a XenDesktop Controller with according privileges necessary 
#
# Call by : Manual  or Scheduled Task
#  
#==============================================================================================
# Load only the snap-ins, which are used
if ((Get-PSSnapin "Citrix.Broker.Admin.*" -EA silentlycontinue) -eq $null) {
try { Add-PSSnapin Citrix.Broker.Admin.* -ErrorAction Stop }
catch { write-error "Error Get-PSSnapin Citrix.Broker.Admin.* Powershell snapin"; Return }
}
# Change the below variables to suit your environment
#==============================================================================================

$maxmachines = "1000"


#machines from DeliveryGroup in Parameter with no Sessions and only VDI (no RDSH aka XenApp)
$machines = Get-BrokerMachine -MaxRecordCount $maxmachines | Where-Object {($_.DesktopGroupName -eq $dg) -and ($_.SessionState -eq $null) -and ($_.SessionSupport -eq "SingleSession")}

Write-Host 'Shutdown 0'$machines' unused maschines of '$dg ''


foreach($machine in $machines) 
{

$machinename = $machine | %{ $_.MachineName }

Write-Host "Action TurnOff will be performed for $machinename  "
New-BrokerHostingPowerAction  -Action ShutDown -MachineName $machinename 
}
