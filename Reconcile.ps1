Add-Type -AssemblyName System.Web

$InputFile  = "$env:USERPROFILE\Downloads\New Text Document.txt"
$OutputFile = "C:\temp\ReconcileSnipeandIntune.csv"

$AssetNames = Get-Content $InputFile

$properties = 'Devicename', 'Serial', 'AssignedTo', 'Model', 'Manufacturer'
$allResults = @()

foreach ($Assetname in $AssetNames) {

    Write-Host "`nChecking asset: $Assetname" -ForegroundColor Cyan

    $intuneasset = Get-MgBetaDeviceManagementManagedDevice -Filter "Devicename eq '$Assetname'"
    $snipeasset  = Get-SnipeitAsset -asset_tag $Assetname

    $intuneobject = [PSCustomObject]@{
        Devicename   = $intuneasset.DeviceName
        Serial       = $intuneasset.SerialNumber
        AssignedTo   = $intuneasset.UserDisplayName
        Model        = $intuneasset.Model
        Manufacturer = $intuneasset.Manufacturer
    }

    $snipeobject = [PSCustomObject]@{
        Devicename   = $snipeasset.asset_tag
        Serial       = $snipeasset.serial
        AssignedTo   = $snipeasset.assigned_to.name
        Model        = $snipeasset.model.name
        Manufacturer = $snipeasset.manufacturer.name
        Status       = $snipeasset.status.name
        Location     = $snipeasset.location.name
    }

    foreach ($prop in $properties) {
        $intuneValue = $intuneobject.$prop
        $snipeValue  = $snipeobject.$prop

        $cleanIntune = [System.Web.HttpUtility]::HtmlDecode([string]$intuneValue)
        $cleanSnipe  = [System.Web.HttpUtility]::HtmlDecode([string]$snipeValue)

        $isMatch = $cleanIntune -like $cleanSnipe

        $row = [PSCustomObject]@{
            AssetTag    = $Assetname
            Devicename  = $intuneobject.Devicename
            Property    = $prop
            IntuneValue = $intuneValue
            SnipeValue  = $snipeValue
            Match       = if ($isMatch) { "Match" } else { "Not Matched" }
            Status      = $snipeasset.status.name
            Location    = $snipeasset.location.name
        }

        $allResults += $row
    }
}

$allResults | Format-Table -AutoSize
$allResults | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host "`nDone. Results saved to $OutputFile" -ForegroundColor Green