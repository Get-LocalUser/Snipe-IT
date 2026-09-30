$AssetTag = Read-Host "Enter the Asset Tag"

$result = Get-SnipeitAsset -asset_tag $AssetTag -ErrorAction SilentlyContinue
if ($null -eq $result) {
    Write-Host "$AssetTag doesn't exist, try again" -ForegroundColor Yellow
    return
}

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