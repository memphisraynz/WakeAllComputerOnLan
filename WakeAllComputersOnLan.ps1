function Get-IPrangeStartEnd 
{ 
    <#  
      .SYNOPSIS   
        Get the IP addresses in a range  
      .EXAMPLE  
       Get-IPrangeStartEnd -start 192.168.8.2 -end 192.168.8.20  
      .EXAMPLE  
       Get-IPrangeStartEnd -ip 192.168.8.2 -mask 255.255.255.0  
      .EXAMPLE  
       Get-IPrangeStartEnd -ip 192.168.8.3 -cidr 24  
    #>  
      
    param (  
      [string]$ip, 
      [int]$cidr  
    )  
      
    function IP-toINT64 () {  
      param ($ip)  
      
      $octets = $ip.split(".")  
      return [int64]([int64]$octets[0]*16777216 +[int64]$octets[1]*65536 +[int64]$octets[2]*256 +[int64]$octets[3])  
    }  
      
    function INT64-toIP() {  
      param ([int64]$int)  
 
      return (([math]::truncate($int/16777216)).tostring()+"."+([math]::truncate(($int%16777216)/65536)).tostring()+"."+([math]::truncate(($int%65536)/256)).tostring()+"."+([math]::truncate($int%256)).tostring() ) 
    }  
      
    if ($ip) {$ipaddr = [Net.IPAddress]::Parse($ip)}  
    if ($cidr) {$maskaddr = [Net.IPAddress]::Parse((INT64-toIP -int ([convert]::ToInt64(("1"*$cidr+"0"*(32-$cidr)),2)))) }
    if ($ip) {$networkaddr = new-object net.ipaddress ($maskaddr.address -band $ipaddr.address)}  
    if ($ip) {$broadcastaddr = new-object net.ipaddress (([system.net.ipaddress]::parse("255.255.255.255").address -bxor $maskaddr.address -bor $networkaddr.address))}  
      
    if ($ip) {  
      $startaddr = IP-toINT64 -ip $networkaddr.ipaddresstostring  
      $endaddr = IP-toINT64 -ip $broadcastaddr.ipaddresstostring  
    } else {  
      $startaddr = IP-toINT64 -ip $start  
      $endaddr = IP-toINT64 -ip $end  
    }  
      
     $temp=""|Select start,end 
     $temp.start=INT64-toIP -int $startaddr 
     $temp.end=INT64-toIP -int $endaddr 
     return $temp 
}

function Get-DefaultIpRange {
    $DefaultNIC = (Get-NetIPConfiguration |
        Where-Object {
            $_.IPv4DefaultGateway -ne $null -and
            $_.NetAdapter.Status -ne "Disconnected"
        }
    ).IPv4Address

    Get-IPrangeStartEnd -ip $DefaultNIC.IPAddress -cidr $DefaultNIC.PrefixLength
}

function Expand-ZIPFile {
    param (
        [string]$Path,
        [string]$DestinationPath
    )

    if (!$DestinationPath) {
        $DestinationPath = [string](Resolve-Path $Path)
        $DestinationPath = $DestinationPath.Substring(0, $DestinationPath.LastIndexOf('.'))
        New-Item -Path $DestinationPath -ItemType Directory | Out-Null
    }
    $shell = New-Object -ComObject Shell.Application
    #$shell.NameSpace($destination).CopyHere($shell.NameSpace($file).Items(), 16);
    $zip = $shell.NameSpace($Path)
    foreach ($item in $zip.items()) {
        $shell.Namespace($DestinationPath).CopyHere($item)
    }
}

function Get-WakeMeOnLan {
    $WakeMeOnLanZIP = "C:\ProgramData\WakeOnLan\WakeMeOnLan.zip"
    $WakeMeOnLanEXE = "C:\ProgramData\WakeOnLan\WakeMeOnLan.exe"
    $DownloadLink = "https://www.nirsoft.net/utils/wakemeonlan-x64.zip"

    if (-not $(Test-Path $WakeMeOnLanEXE)) {
        #Create Directory
        $Split = $WakeMeOnLanEXE.Split("\\")
        New-Item -Path $(([string]$split[0..($Split.count-2)]) -replace(" ","\")) -ItemType Directory -Force | Out-Null

        #Download File
        (New-Object System.Net.WebClient).DownloadFile($DownloadLink, $WakeMeOnLanZIP)
        #Unzip
        Expand-ZIPFile -Path $WakeMeOnLanZIP -DestinationPath $(([string]$split[0..($Split.count-2)]) -replace(" ","\"))
        #Remove all except exe file
        Remove-Item -Path "$(([string]$split[0..($Split.count-2)]) -replace(" ","\"))\*" -Exclude "*.exe" -Confirm:$false
    }    
}

function Start-ComputerScan {
    $WakeMeOnLanEXE = "C:\ProgramData\WakeOnLan\WakeMeOnLan.exe"

    #Download WakeMeOnLan if required
    Get-WakeMeOnLan
    
    #Get IP Range
    $IPRange = Get-DefaultIpRange

    & $WakeMeOnLanEXE /scan /UseIPAddressesRange 1 /IPAddressFrom $IPRange.start /IPAddressTo $IPRange.end
}

function Start-WakeAllComputers {
    $WakeMeOnLanEXE = "C:\ProgramData\WakeOnLan\WakeMeOnLan.exe"
    
    #Download WakeMeOnLan if required
    Get-WakeMeOnLan
        
    #Get IP Range
    $IPRange = Get-DefaultIpRange

    & $WakeMeOnLanEXE /wakeupiprange $IPRange.start $IPRange.end
}
