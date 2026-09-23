# Get list of assets by Asset Tag
$assets = Get-Content -Path "$env:USERPROFILE\Downloads\New Text Document.txt"

$results = foreach ($asset in $assets) {
    $result = Get-SnipeitAsset -asset_tag $asset

    [PSCustomObject]@{
        "Asset Tag"     = $result.asset_tag
        "Serial"        = $result.serial
        "Model"         = $result.model.name
        "Category"      = $result.category.name
        "Manufacturer"  = $result.manufacturer.name
        "Status"        = $result.status.name
        "Location"      = $result.location.name
        "Assigned To"   = $result.assigned_to.name
        "Email"         = $result.assigned_to.username
        "Condition"     = if ("" -eq $result.custom_fields.'Asset Condition (Use only when Surplusing)'.value) { "N/A" } else { $result.custom_fields.'Asset Condition (Use only when Surplusing)'.value }
        "Working?"      = if ("" -eq $result.custom_fields.'Working? (Use only when Surplusing)'.value) { "N/A" } else { $result.custom_fields.'Working? (Use only when Surplusing)'.value }
    }
}

$results | Export-Csv -Path "C:\temp\assetinfobulk.csv" -NoTypeInformation
if ($?) {
    Write-Host "Results exported to C:\temp\assetinfobulk.csv" -ForegroundColor Yellow
} else {
    Write-Host "Export failed AHHHHH" -ForegroundColor Red
}