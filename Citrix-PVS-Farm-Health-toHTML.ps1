#==============================================================================================
# Created on: 08.2014            Version: 1.63
# Created by: Sacha Thomet, blog.appcloud.ch / sachathomet.ch
# Filename: Citrix-PVS-Farm-Health-toHTML.ps1
#
# Special Thanks to:
# - Jason Poyner ... I've borrowed parts of the script and ideas to create this 
#   PVS health check script. Check his excellent XenApp Health Check @ techblog.deptive.co.nz.
# - Martin Hartmann to share his PowerShell KnowHow with me.
#
# Description: This script checks Citrix Provisioning Server, Farm, vDisk & Target devices.
#
# Prerequisite: Script must run on a PVS server, where MCLI snap-in is registered.
# Register SnapIn with command: C:\WINDOWS\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe 
# "C:\Program Files\Citrix\Provisioning Services Console\McliPSSnapIn.dll"
#
# Call by : Scheduled Task, e.g. once a day
#
# Change Log: 
#      V1.1:  Consolidated code
#      V1.2:  Add possibility to check only specified Versions
#      V1.3:  New version after Citrix Synergy 2015 GeekOvation Award nomination. 
#             With correction of typos and add some documentation lines. 
#      V1.4:  Possibility for multiple stores (Thanks to Kafedzhiev  for the code) (08-2015) 
#      V1.5:  Show create date of vDisk, FileName and the count of the used vDisk (09-2015)
#      V1.6:  Add RamCache used from each target, added code by Jonathan Pitre, 
#             code from Matthew Nics http://mattnics.com/?p=414 (10-2015) 
#      V1.61: Changed RamCache to general WriteCache, add possibility to get Size of Cache on HD
#      V1.62: Correction in Header to show correct farm name instead a "6", correction in 
#             LoadBalancingAlgorithm, Error if a disk is assigned fix to a server. 
#      V1.63: Check of Stream-, Soap-, and TFTP-Service (12-2015)
#
#
#      THIS SCRIPT IS FOR PVS 7.6 AND BELOW. ASK FOR BETA VERSION OF PVS 7.7 HEALTH CHECK SCRIPT 
#      IF YOU ARE USING THE TECHPREVIEW OF PVS 7.7 WITH COMPLETE NEW POSH-IMPLEMENTATION
#
#
#==============================================================================================
if ((Get-PSSnapin "McliPSSnapIn" -EA silentlycontinue) -eq $null) {
try { Add-PSSnapin McliPSSnapIn -ErrorAction Stop }
catch { write-error "Error loading PVS McliPSSnapIn PowerShell snapin"; Return }
}
# Change the below variables to suit your environment
#==============================================================================================
# Target Device Health Check threshold:
$retrythresholdWarning= "15" # define the Threshold from how many retries the color switch to red
  
# Include for Device Collections, type "every" if you want to see every Collection 
# Example1: $Collections = @("XA65","XA5")
# Example2: $Collections = @("every")
$Collections = @("every")
  
# Information about the site you want to check:
$siteName="site" # site name on which the according Store is.
   
# E-mail report details
$emailFrom = "email@company.ch"
$emailTo = "citrix@company.ch"#,"sacha.thomet@appcloud.ch"
$smtpServer = "mailrelay.company.ch"
$emailSubjectStart = "PVS Farm Report"
$mailprio = "High"
#==============================================================================================
  
$currentDir = Split-Path $MyInvocation.MyCommand.Path
$logfile = Join-Path $currentDir ("PVSHealthCheck.log")
$resultsHTM = Join-Path $currentDir ("PVSFarmReport.htm")
$errorsHTM = Join-Path $currentDir ("PVSHealthCheckErrors.htm") 
  
#Header for Table 1 "Target Device Checks"
$TargetfirstheaderName = "TargetDeviceName"
$TargetheaderNames = "CollectionName", "Ping", "Retry", "vDisk_PVS", "vDisk_Version", "WriteCache", "PVSServer"
$TargetheaderWidths = "4", "4", "4", "4", "2" , "4", "4"
$Targettablewidth = 1200
#Header for Table 2 "vDisk Checks"
$vDiksFirstheaderName = "vDisk"
$vDiskheaderNames = "Store", "vDiskFileName", "deviceCount", "CreateDate" , "ReplState", "LoadBalancingAlgorithm", "WriteCacheType"
$vDiskheaderWidths = "4", "8", "2","4", "4", "4", "4"
$vDisktablewidth = 1200
#Header for Table 3 "PV Server"
$PVSfirstheaderName = "PVS Server"
$PVSHeaderNames = "Ping", "Active", "deviceCount","SoapService","StreamService","TFTPService"
$PVSheaderWidths = "4", "4", "4","4","4","4"
$PVStablewidth = 600
#Header for Table 4 "Farm"
$PVSFirstFarmheaderName = "FarmChecks"
$PVSFarmHeaderNames = "Setting", "Value"
$PVSFarmWidths = "4", "8", "8"
$PVSFarmTablewidth = 400
  
#==============================================================================================
#log function
function LogMe() {
Param(
[parameter(Mandatory = $true, ValueFromPipeline = $true)] $logEntry,
[switch]$display,
[switch]$error,
[switch]$warning,
[switch]$progress
)
  
 if ($error) {
$logEntry = "[ERROR] $logEntry" ; Write-Host "$logEntry" -Foregroundcolor Red}
elseif ($warning) {
Write-Warning "$logEntry" ; $logEntry = "[WARNING] $logEntry"}
elseif ($progress) {
Write-Host "$logEntry" -Foregroundcolor Green}
elseif ($display) {
Write-Host "$logEntry" }
   
 #$logEntry = ((Get-Date -uformat "%D %T") + " - " + $logEntry)
$logEntry | Out-File $logFile -Append
}
#==============================================================================================
function Ping([string]$hostname, [int]$timeout = 200) {
$ping = new-object System.Net.NetworkInformation.Ping #creates a ping object
try {
$result = $ping.send($hostname, $timeout).Status.ToString()
} catch {
$result = "Failure"
}
return $result
}
#==============================================================================================
Function writeHtmlHeader
{
param($title, $fileName)
$date = ( Get-Date -format R)
$head = @"
<html>
<head>
<meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>
<title>$title</title>
 
<STYLE TYPE="text/css">
<!-- td { font-family: Tahoma; font-size: 11px; border-top: 1px solid #999999; border-right: 1px solid #999999; border-bottom: 1px solid #999999; border-left: 1px solid #999999; padding-top: 0px; padding-right: 0px; padding-bottom: 0px; padding-left: 0px; overflow: hidden; } body { margin-left: 5px; margin-top: 5px; margin-right: 0px; margin-bottom: 10px; table { table-layout:fixed; border: thin solid #000000; } -->
</style>
 
</head>
<body>
 
<table width='1200'>
 
<tr bgcolor='#CCCCCC'>
 
<td colspan='7' height='48' align='center' valign="middle">
<font face='tahoma' color='#003399' size='4'>
<strong>$title - $date</strong></font>
</td>
 
</tr>
 
</table>
 
"@
$head | Out-File $fileName
}
# ==============================================================================================
Function writeTableHeader
{
param($fileName, $firstheaderName, $headerNames, $headerWidths, $tablewidth)
$tableHeader = @"
 
<table width='$tablewidth'>
<tbody>
 
<tr bgcolor=#CCCCCC>
 
<td width='6%' align='center'><strong>$firstheaderName</strong></td>
 
"@
$i = 0
while ($i -lt $headerNames.count) {
$headerName = $headerNames[$i]
$headerWidth = $headerWidths[$i]
$tableHeader += "
<td width='" + $headerWidth + "%' align='center'><strong>$headerName</strong></td>
 
"
$i++
}
$tableHeader += "</tr>
 
"
$tableHeader | Out-File $fileName -append
}
# ==============================================================================================
Function writeTableFooter
{
param($fileName)
"</table>
 
"| Out-File $fileName -append
}
#==============================================================================================
Function writeData
{
param($data, $fileName, $headerNames)
   
 $data.Keys | sort | foreach {
$tableEntry += "
<tr>"
$computerName = $_
$tableEntry += ("
<td bgcolor='#CCCCCC' align=center><font color='#003399'>$computerName</font></td>
 
")
#$data.$_.Keys | foreach {
$headerNames | foreach {
#"$computerName : $_" | LogMe -display
try {
if ($data.$computerName.$_[0] -eq "SUCCESS") { $bgcolor = "#387C44"; $fontColor = "#FFFFFF" }
elseif ($data.$computerName.$_[0] -eq "WARNING") { $bgcolor = "#FF7700"; $fontColor = "#FFFFFF" }
elseif ($data.$computerName.$_[0] -eq "ERROR") { $bgcolor = "#FF0000"; $fontColor = "#FFFFFF" }
else { $bgcolor = "#CCCCCC"; $fontColor = "#003399" }
$testResult = $data.$computerName.$_[1]
}
catch {
$bgcolor = "#CCCCCC"; $fontColor = "#003399"
$testResult = ""
}
   
 $tableEntry += ("
<td bgcolor='" + $bgcolor + "' align=center><font color='" + $fontColor + "'>$testResult</font></td>
 
")
}
   
 $tableEntry += "</tr>
 
"
   
   
 }
   
 $tableEntry | Out-File $fileName -append
}
# ==============================================================================================
Function writeHtmlFooter
{
param($fileName)
@"
 
<table>
 
<table width='1200'>
 
<tr bgcolor='#CCCCCC'>
 
<td colspan='7' height='25' align='left'>
 
<font face='courier' color='#000000' size='2'><strong>Retry Threshold =</strong></font><font color='#003399' face='courier' size='2'> $retrythresholdWarning
<tr></font>
 
<tr bgcolor='#CCCCCC'>
</td>
 
</tr>
 
 
<tr bgcolor='#CCCCCC'>
</tr>
 
</table>
 
</body>
</html>
"@ | Out-File $FileName -append
}
  
#==============================================================================================
# == MAIN SCRIPT ==
#==============================================================================================
rm $logfile -force -EA SilentlyContinue
"Begin with Citrix Provisioning Services HealthCheck" | LogMe -display -progress
" " | LogMe -display -progress
  
   
  
# ======= PVS Target Device Check ========
"Check PVS Target Devices" | LogMe -display -progress
" " | LogMe -display -progress
$allResults = @{}
$pvsdevices = mcli-get device -f deviceName | Select-String deviceName
foreach($target in $pvsdevices)
 {
   
 $tests = @{} 
   
 # Check to see if the server is in an excluded folder path
$target | Select-String deviceName 
 $_targetshort = $target -replace "deviceName: ",""
 $pvcollectionName = mcli-get deviceinfo -p devicename=$_targetshort | select-string collectionName
$short_collectionName = $pvcollectionName.ToString().TrimStart("collectionName: ")
   
 #Only Check Servers in defined Collections: 
 if ($Collections -contains $short_collectionName -Or $Collections -contains "every") { 
   
  
 $target | Select-String deviceName 
 $_targetshort = $target -replace "deviceName: ",""
$_targetshort | LogMe -display -progress
   
 # Ping server 
 $result = Ping $_targetshort 100
if ($result -ne "SUCCESS") { $tests.Ping = "ERROR", $result }
else { $tests.Ping = "SUCCESS", $result 
 }
   
 #CollectionName
$pvcollectionName = mcli-get deviceinfo -p devicename=$_targetshort | select-string collectionName
$short_collectionName = $pvcollectionName.ToString().TrimStart("collectionName: ")
$tests.CollectionName = "NEUTRAL", "$short_collectionName"
 # Test Retries
$devicestatus = mcli-get deviceinfo -p devicename=$_targetshort -f status
$retrycount = $devicestatus[4].TrimStart("status: ") -as [int]
if ($retrycount -lt $retrythresholdWarning) { $tests.Retry = "SUCCESS", "$retrycount Retry = OK" }
else { $tests.Retry = "WARNING","$retrycount retries!" }
   
 #Check assigned Image
$devicediskFileName = mcli-get deviceinfo -p devicename=$_targetshort | select-string diskFileName
$short_devicediskFileName = $devicediskFileName.ToString().TrimStart("diskFileName: ")
$tests.vDisk_PVS = "SUCCESS", "$short_devicediskFileName"
 #Check assigned Image Version
$devicediskVersion = mcli-get deviceinfo -p devicename=$_targetshort | select-string diskVersion:
$short_devicediskVersion = $devicediskVersion.ToString().TrimStart("diskVersion: ")
$tests.vDisk_Version = "SUCCESS", "$short_devicediskVersion"
 #PVS-Server
$PVSServername = mcli-get deviceinfo -p devicename=$_targetshort | select-string serverName
$short_PVSServername = $PVSServername.ToString().TrimStart("serverName: ")
$tests.PVSServer = "Neutral", "$short_PVSServername"
 
 
################ PVS WriteCache SECTION ###############
 
         
        if (test-path \\$_targetshort\c$\Personality.ini)
        {
 
            $wconhd = ""
            $wconhd = Get-Content \\$_targetshort\c$\Personality.ini | Where-Object  {$_.Contains("WriteCacheType=4") }
             
            If ($wconhd -match "$WriteCacheType=4") {Write-Host Cache on HDD
             
            #WWC on HD is $wconhd
 
                # Relative path to the PVS vDisk write cache file
                $PvsWriteCache   = "d$\.vdiskcache"
                # Size of the local PVS write cache drive
                $PvsWriteMaxSize = 10gb # size in GB
             
                $PvsWriteCacheUNC = Join-Path "\\$_targetshort" $PvsWriteCache 
                $CacheDiskexists  = Test-Path $PvsWriteCacheUNC
                if ($CacheDiskexists -eq $True)
                {
                    $CacheDisk = [long] ((get-childitem $PvsWriteCacheUNC -force).length)
                    $CacheDiskGB = "{0:n2}GB" -f($CacheDisk / 1GB)
                    "PVS Cache file size: {0:n2}GB" -f($CacheDisk / 1GB) | LogMe
                    #"PVS Cache max size: {0:n2}GB" -f($PvsWriteMaxSize / 1GB) | LogMe -display
                    if($CacheDisk -lt ($PvsWriteMaxSize * 0.5))
                    {
                       "WriteCache file size is low" | LogMe
                       $tests.WriteCache = "SUCCESS", $CacheDiskGB
                    }
                    elseif($CacheDisk -lt ($PvsWriteMaxSize * 0.8))
                    {
                       "WriteCache file size moderate" | LogMe -display -warning
                       $tests.WriteCache = "WARNING", $CacheDiskGB
                    }   
                    else
                    {
                       "WriteCache file size is high" | LogMe -display -error
                       $tests.WriteCache = "ERORR", $CacheDiskGB
                    }
                }              
                
                $Cachedisk = 0
                
                $VDISKImage = get-content \\$_targetshort\c$\Personality.ini | Select-String "Diskname" | Out-String | % { $_.substring(12)}
                if($VDISKImage -Match $DefaultVDISK){
                    "Default vDisk detected" | LogMe
                    $tests.vDisk = "SUCCESS", $VDISKImage
                } else {
                    "vDisk unknown"  | LogMe -display -error
                    $tests.vDisk = "SUCCESS", $VDISKImage
                }   
             
            }
            else 
            {Write-Host Cache on Ram
             
            #RAMCache
            #Get-RamCache from each target, code from Matthew Nics http://mattnics.com/?p=414
            $RAMCache = [math]::truncate((Get-WmiObject Win32_PerfFormattedData_PerfOS_Memory -ComputerName $_targetshort).PoolNonPagedBytes /1MB)
            $tests.WriteCache = "Neutral", "$RamCache MB on Ram"
         
            }
         
        }
        else 
        {Write-Host WriteCache not readable
        $tests.WriteCache = "Neutral", "Cache not readable" 
        }
        ############## END PVS WriteCache SECTION #############
             
 
#Forward results to $allResult array which will be written in HTM-File
$allResults.$_targetshort = $tests
 }
}
# ======= PVS vDisk Check #==================================================================
"Check PVS vDisks" | LogMe -display -progress
" " | LogMe -display -progress
  
$storenames = mcli-get store | Select-string storename
$vdiskResults = @{}
foreach ($storenameA in $storenames)
{
$storename = $storenameA -replace "storename: ",""
$storeid = mcli-get store -p storeName=$storename | Select-String storeId
$storeid_short = $storeid -replace "storeId: ",""
$alldisks = Mcli-Get disklocator -p siteName=$siteName, storeId=$storeid_short | Select-String diskLocatorName
foreach($disk in $alldisks)
{
$disk1 = $disk | Select-String diskLocatorName
$disklocator_short = $disk1 -replace "diskLocatorName: ",""
foreach($diksloc in $disklocator_short)
{
   
 $VDtests = @{} 
   
 $DiskVersion = Mcli-Get DiskVersion -p diskLocatorName=$disklocator_short, siteName=$siteName, storeName=$storename
$diskreplstatus = $DiskVersion | Select-String goodInventoryStatus
$diskreplstatus_short = $diskreplstatus -replace "goodInventoryStatus: ","" 
   
   
 $disklocator_short
$diskreplstatus_short
   
 # vDiskFileName & createDate 
 $pathA = mcli-get store -p storeName=$storename | Select-String path -casesensitive
$path = $pathA -replace "path: ",""
   
 $diskfilenameA = Mcli-Get DiskVersion -p diskLocatorName=$disklocator_short, siteName=$siteName, storeName=$storename | Select-String diskFileName 
 $diskfilename = $diskfilenameA -replace "diskFileName: ","
"
   
 $createDateA = Mcli-Get DiskVersion -p diskLocatorName=$disklocator_short, siteName=$siteName, storeName=$storename | Select-String createDate 
 $createDate = $createDateA -replace "createDate: ","
"
   
 $VDtests.vDiskFileName = "OK", " $diskfilename"
Write-Host ("Path is $path $disklocator_short $diskfilename")
   
 $VDtests.createDate = "OK", " $createDate"
Write-Host ("Path is $path $disklocator_short $createDate")
   
 $vdiskResults.$disklocator_short = $VDtests
   
   
   
 #Check if correct replicated
if($diskreplstatus_short -eq 1 ){
"$disklocator_short correct replicated" | LogMe
$VDtests.ReplState = "SUCCESS", "Replication is OK"
   
 } else {
"$disklocator_short not correct replicated " | LogMe -display -error
$VDtests.ReplState = "ERROR", "Replication is NOT OK"
}
 # Check deviceCount: 
 $diskdevicecount = $DiskVersion | Select-String deviceCount
$diskdevicecounts_short = $diskdevicecount -replace "deviceCount: ","
" 
 $VDtests.deviceCount = "OK", "$diskdevicecounts_short "
   
   
 #Label Storename 
 $VDtests.Store = "OK", " $storename "
Write-Host ("Store is $storename")
   
 $vdiskResults.$disklocator_short = $VDtests
   
   
# Check for LB-Algorithm
# ----------------------
# Feel free to change it to the the from you desired State (e.g.Exchange a SUCCESS with a WARNING)
# In this default configuration "BestEffort" or "None" is desired and appears green on the output.
# is desired)
 
#ServeName must be empty! otherwise no LB is active!
$LBnoServer = ""
$LBnoServer_short = ""
$LBnoServer = Mcli-Get disklocator -p siteName=$siteName, storeName=$storename, diskLocatorName=$disklocator_short | Select-String serverName
$LBnoServer_short = $LBnoServer -replace "serverName: ","" 
Write-Host ("vDisk is fix assigned to $LBnoServer")
#not assigned to a server
if ($LBnoServer_short -eq "")
        {
        $LBAlgo = Mcli-Get disklocator -p siteName=$siteName, storeName=$storename | Select-String subnetAffinity
        $LBAlgo_short = $LBAlgo -replace "subnetAffinity: ","" 
           
        #SubnetAffinity: 1=Best Effort, 2= fixed, 0=none
        if($LBAlgo_short -eq 1 ){
        "LB-Algorythm is set to BestEffort" | LogMe
        $VDtests.LoadBalancingAlgorithm = "SUCCESS", "LB is set to BEST EFFORT"} 
           
         elseif($LBAlgo_short -eq 2 ){
        "LB-Algorythm is set to fixed" | LogMe
        $VDtests.LoadBalancingAlgorithm = "WARNING", "LB is set to FIXED"}
           
         elseif($LBAlgo_short -eq 0 ){
        "LB-Algorythm is set to none" | LogMe
        $VDtests.LoadBalancingAlgorithm = "SUCCESS", "LB is set to NONE, least busy server is used"}
 
        }
 
#Disk fix assigned to a server
else
{
$VDtests.LoadBalancingAlgorithm = "ERROR", "vDisk is fix assigned to $LBnoServer, no LoadBalancing!"}
}
   
   
   
 #Check for WriteCacheType
# -----------------------
# Feel free to change it to the the from you desired State (e.g.Exchange a SUCCESS with a WARNING)
# In this default configuration, only "Cache to Ram with overflow" and "Cache to Device Hard disk" is desired and appears green on the output.
   
 $WriteCacheType = Mcli-Get DiskInfo -p diskLocatorName=$disklocator_short, siteName=$siteName, storeName=$storename
$WriteCacheType_short = $WriteCacheType -replace "WriteCacheType: ",""
   
 #$WriteCacheType 9=RamOfToHD 0=PrivateMode 4=DeviceHD 8=DeviceHDPersistent 3=DeviceRAM 1=PVSServer 7=ServerPersistent 
   
 if($WriteCacheType_short -eq 9 ){
"WC is set to Cache to Device Ram with overflow to HD" | LogMe
$VDtests.WriteCacheType = "SUCCESS", "WC Cache to Ram with overflow to HD"}
   
 elseif($WriteCacheType_short -eq 0 ){
"WC is not set because vDisk is in PrivateMode (R/W)" | LogMe
$VDtests.WriteCacheType = "Error", "vDisk is in PrivateMode (R/W) "}
   
 elseif($WriteCacheType_short -eq 4 ){
"WC is set to Cache to Device Hard Disk" | LogMe
$VDtests.WriteCacheType = "SUCCESS", "WC is set to Cache to Device Hard Disk"}
   
 elseif($WriteCacheType_short -eq 8 ){
"WC is set to Cache to Device Hard Disk Persistent" | LogMe
$VDtests.WriteCacheType = "Error", "WC is set to Cache to Device Hard Disk Persistent"}
   
 elseif($WriteCacheType_short -eq 3 ){
"WC is set to Cache to Device Ram" | LogMe
$VDtests.WriteCacheType = "WARNING", "WC is set to Cache to Device Ram"}
   
 elseif($WriteCacheType_short -eq 1 ){
"WC is set to Cache to PVS Server HD" | LogMe
$VDtests.WriteCacheType = "Error", "WC is set to Cache to PVS Server HD"}
   
 elseif($WriteCacheType_short -eq 7 ){
"WC is set to Cache to PVS Server HD Persistent" | LogMe
$VDtests.WriteCacheType = "Error", "WC is set to Cache to PVS Server HD Persistent"}
}
}
   
   
 
# ======= PVS Server Check ==================================================================
"Check PVS Servers" | LogMe -display -progress
" " | LogMe -display -progress
  
$PVSResults = @{}
$allPVSServer = mcli-get server | Select-String serverName
foreach($PVServerName in $allPVSServer)
{
$PVStests = @{} 
   
 $PVServerName1 = $PVServerName | Select-String serverName
$PVServerName_short = $PVServerName1 -replace "serverName: ","" 
 $PVServerName_short
   
 # Ping server 
 $result = Ping $PVServerName_short 100
if ($result -ne "SUCCESS") { $PVStests.Ping = "ERROR", $result }
else { $PVStests.Ping = "SUCCESS", $result 
 } 
   
 #Check PVS Service Status
$serverstatus = mcli-get ServerStatus -p serverName=$PVServerName_short -f status
$actviestatus = $serverstatus[4].TrimStart("status: ") -as [int]
if ($actviestatus -eq 1) { $PVStests.Active = "SUCCESS", "active" }
else { $PVStests.Active = "Error","inactive" }
 
# Check services
        if ((Get-Service -Name "soapserver" -ComputerName $PVServerName_short).Status -Match "Running") {
            "SoapService running..." | LogMe
            $PVStests.SoapService = "SUCCESS", "Success"
        } else {
            "SoapService service stopped"  | LogMe -display -error
            $PVStests.SoapService = "ERROR", "Error"
        }
             
        if ((Get-Service -Name "StreamService" -ComputerName $PVServerName_short).Status -Match "Running") {
            "StreamService service running..." | LogMe
            $PVStests.StreamService = "SUCCESS","Success"
        } else {
            "StreamService service stopped"  | LogMe -display -error
            $PVStests.StreamService = "ERROR","Error"
        }
             
        if ((Get-Service -Name "BNTFTP" -ComputerName $PVServerName_short).Status -Match "Running") {
            "TFTP service running..." | LogMe
            $PVStests.TFTPService = "SUCCESS","Success"
        } else {
            "TFTP  service stopped"  | LogMe -display -error
            $PVStests.TFTPService = "ERROR","Error"
         
 }
   
 #Check PVS deviceCount
$serverdevicecount = mcli-get ServerStatus -p serverName=$PVServerName_short -f deviceCount
$numberofdevices = $serverdevicecount[4].TrimStart("deviceCount: ") -as [int]
if ($numberofdevices -gt 1) { $PVStests.deviceCount = "SUCCESS", " $numberofdevices active" }
else { $PVStests.deviceCount = "WARNING","No devices on this server" }
   
   
   
 $PVSResults.$PVServerName_short = $PVStests
   
}
# ======= PVS Farm Check ====================================================================
"Read some PVS Farm Parameters" | LogMe -display -progress
" " | LogMe -display -progress
$PVSFarmResults = @{}
$PVSfarms = mcli-get Farm #| Select-String FarmName
 
$farmname = mcli-get Farm | Select-String FarmName
$farmname_short = $farmname -replace "farmName: ",""
 
$Nr=0
foreach($PVSFarm in $PVSfarms)
{
$PVSFarmtests = @{}
# remove not needed record parts
if ($PVSFarm -like '*description*'){continue;}
if ($PVSFarm -like '*record*'){continue;}
if ($PVSFarm -like '*failover*'){continue;}
if ($PVSFarm -like '*executing*'){continue;}
if ($PVSFarm -like '*defaultSiteName*'){continue;}
if ($PVSFarm -like '*autoAddEnabled*'){continue;}
if ($PVSFarm -like '*role*'){continue;}
if ($PVSFarm -like '*audit*'){continue;}
if ($PVSFarm -like '*defaultSiteId*'){continue;}
if ($PVSFarm -like '*maxVersions*'){continue;}
if ($PVSFarm -like '*databaseInstanceName*'){continue;}
if ($PVSFarm -like '*farmId*'){continue;}
if ($PVSFarm -like '*merge*'){continue;}
if ($PVSFarm -like '*adGroups*'){continue;}
 if ($PVSFarm -ne '') {
$Nr += 1
$arr = $PVSFarm -split ': '
$farmsetting = $arr[0]
$PVSFarmtests.Setting = "NEUTRAL", "$farmsetting"
$arr = $PVSFarm -split ': '
$farmsettingvalue = $arr[1]
$PVSFarmtests.Value = "NEUTRAL", "$farmsettingvalue"
$farmnr=$Nr
$PVSFarmResults.$farmnr = $PVSFarmtests
}
}
  
  
  
# ======= Write all results to an html file =================================================
Write-Host ("Saving results to html report: " + $resultsHTM)
writeHtmlHeader "PVS Farm Report $farmname_short" $resultsHTM
writeTableHeader $resultsHTM $TargetFirstheaderName $TargetheaderNames $TargetheaderWidths $TargetTablewidth
$allResults | sort-object -property collectionName | % { writeData $allResults $resultsHTM $TargetheaderNames}
writeTableFooter $resultsHTM
writeTableHeader $resultsHTM $vDiksFirstheaderName $vDiskheaderNames $vDiskheaderWidths $vDisktablewidth
$vdiskResults | sort-object -property ReplState | % { writeData $vdiskResults $resultsHTM $vDiskheaderNames }
writeTableFooter $resultsHTM
writeTableHeader $resultsHTM $PVSFirstheaderName $PVSheaderNames $PVSheaderWidths $PVStablewidth
$PVSResults | sort-object -property PVServerName_short | % { writeData $PVSResults $resultsHTM $PVSheaderNames}
writeTableFooter $resultsHTM
  
writeTableHeader $resultsHTM $PVSFirstFarmheaderName $PVSFarmHeaderNames $PVSFarmWidths $PVSFarmTablewidth
$PVSFarmResults | % { writeData $PVSFarmResults $resultsHTM $PVSFarmHeaderNames}
writeTableFooter $resultsHTM
writeHtmlFooter $resultsHTM
#send email
$emailSubject = ("$emailSubjectStart - $farmname_short - " + (Get-Date -format R))
$mailMessageParameters = @{
From = $emailFrom
To = $emailTo
Subject = $emailSubject
SmtpServer = $smtpServer
Body = (gc $resultsHTM) | Out-String
Attachment = $resultsHTM
}
# Send mail if you wish
Send-MailMessage @mailMessageParameters -BodyAsHtml -Priority $mailprio
