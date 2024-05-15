$mapping = @{}
$drivers = Get-WindowsDriver -Online
foreach($driver in $drivers) {
  $inf = $driver.Driver
  $file = $driver.OriginalFileName
  $mapping[$inf] = $file
}

$dism_command = "dism /Image:work\mnt /Add-Driver"
$snippet = ""
$init_snippet = ""

foreach($group in Get-CimInstance win32_PnPSignedDriver | Where-Object{$_.InfName -like 'oem*.inf' } | Group-Object -Property InfName | Sort-Object -Property Name) {
    $driver = $group.Group[0]
    $name = $driver.DeviceName
    $inf = $driver.InfName
    $filename = $mapping[$inf]
    $exportfilename = $filename.Replace("C:\Windows\System32\DriverStore\FileRepository\", "work\driver\")
    Write-Host "Found active driver ${inf} => ${name}"

    if($init_snippet -eq "") {
        $init_snippet = "SET IMAGEFACTORY_DRIVERS=${exportfilename}"
    } else {
        $init_snippet = "${init_snippet} ${exportfilename}"
    }

    $snippet = "${snippet}@ECHO Add drivers for ${name}`n"
    $dism_command = "${dism_command} /Driver:${exportfilename}"
}

$instructions = "Add the following to the build.bat, replacing the current SET IMAGEFACTORY_DRIVERS line:`n8>-----8>-----8>-----8>-----8>-----8>-----`n${init_snippet}`n<8-----<8-----<8-----<8-----<8-----<8-----`n`nAdd the following to the buid.bat script in the section Customize: Add drivers`n8>-----8>-----8>-----8>-----8>-----8>-----`n${snippet}`n<8-----<8-----<8-----<8-----<8-----<8-----`n`nOr use the following script`n${dism_command}"

Write-Host $instructions

$instructions | Out-File -FilePath $PSScriptRoot\driver-snippet.txt
