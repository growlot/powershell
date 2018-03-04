# If a computer is at workspace, -Disable
# else if a computer is at home, no parameter

Param(
      [Switch]$Disable
      )
      
$rootRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Network\{4D36E972-E325-11CE-BFC1-08002BE10318}"
$subTypePropertyName = "MediaSubType"

[Object[]]$wirelessGuids = Get-ChildItem -Path $rootRegPath -Recurse `
            | Where-Object { `
                ($tmpPath = ($rootRegPath + "\" + $_.PSChildName + "\Connection")) -and `
                (Test-Path $tmpPath) -and `
                ($tempKey = Get-Item -LiteralPath $tmpPath) -and `
                (($tempValue = $tempKey.GetValue($subTypePropertyName, $null)) -eq 2) `
               } `
            | Select-Object -Expand PSChildName

if (!$wirelessGuids) {
    Write-Warning 'There is no wireless adapter!'
    Exit 
 }

if ($wirelessGuids -is [string]) { [Object[]]$wirelessGuids = $wirelessGuids }
[Collections.Generic.List[Object]]$wirelessGuids = $wirelessGuids

$wirelessAdapters = Get-WmiObject -Class Win32_NetworkAdapter -filter "PNPDeviceID LIKE 'PCI%' or PNPDeviceID LIKE 'USB%'" `
            | Where-Object {$wirelessGuids.Contains($_.GUID)}

if (!$wirelessAdapters) {
    Write-Warning 'There is no wireless adapter!'
    Exit 
 }

if ($Disable) { $wirelessAdapters.Disable() }
else { $wirelessAdapters.Enable() }
