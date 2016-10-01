<#
.SYNOPSIS
This is a Powershell to change the PowerState of VDI's or XenApp Servers in a PowerManaged XenDesktop 7.x environment accodring to Tags.

.DESCRIPTION
The script need the parameters Tags and poweroperation. 
This script must run on a desktop broker. 


.EXAMPLE
.\PowerOperation-DependingMachineTags.ps1 AlwaysOnline TurnOn

#>
param([string]$tags=$(throw "Tags parameter is required"), [string]$poweroperation=$(throw "Power operaton parameter is required"))
#==============================================================================================
# Created on: 09.2016 Version: 0.2
# Created by: Sacha Thomet
# File name: PowerOperation-DependingMachineTags.ps1
#
# Description:  This is a Powershell to change the PowerState of VDI's or XenApp Servers in 
#               a PowerManaged XenDesktop 7.x environment accodring to Tags.
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

#$tags = "AlwaysOnline"
#$poweroperation = "TurnOn"

$machines = Get-BrokerMachine -MaxRecordCount $maxmachines | Where-Object {$_.tags -eq $tags }


foreach($machine in $machines) 
{

$machinename = $machine | %{ $_.MachineName }

Write-Host "Action $poweroperation will be performed for $machinename  "
New-BrokerHostingPowerAction  -Action $poweroperation -MachineName $machinename 
}
