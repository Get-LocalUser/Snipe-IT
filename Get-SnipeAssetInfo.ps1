function Get-SnipeAssetInfo {
    param (
        [string]$AssetTag
    )

    $result = Get-SnipeitAsset -asset_tag $AssetTag -ErrorAction SilentlyContinue

    if ($null -eq $result) {
        return $null
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
        "Condition"     = if ([string]::IsNullOrWhiteSpace($result.custom_fields.'Asset Condition (Use only when Surplusing)'.value)) { "N/A" } else { $result.custom_fields.'Asset Condition (Use only when Surplusing)'.value }
        "Working?"      = if ([string]::IsNullOrWhiteSpace($result.custom_fields.'Working? (Use only when Surplusing)'.value)) { "N/A" } else { $result.custom_fields.'Working? (Use only when Surplusing)'.value }
    }
}


# ==========================
# Choose Lookup Mode
# ==========================

Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "       Snipe-IT Asset Lookup"        -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Single Asset"
Write-Host "2. Bulk Assets"
Write-Host ""

$choice = Read-Host "Choose an option (1 or 2)"

switch ($choice) {

    # ==========================
    # Single Asset
    # ==========================
    "1" {

        $AssetTag = Read-Host "Enter the Asset Tag"

        $assetInfo = Get-SnipeAssetInfo -AssetTag $AssetTag

        if ($null -eq $assetInfo) {
            Write-Host ""
            Write-Host "$AssetTag doesn't exist, try again." -ForegroundColor Yellow
            return
        }

        Write-Host ""
        $assetInfo | Format-List
    }


    # ==========================
    # Bulk Assets
    # ==========================
    "2" {

        $assetFile = Read-Host "Enter path of file containing asset tags"
        $assetFile = $assetFile.Trim('"')

        if (-not (Test-Path $assetFile)) {
            Write-Host ""
            Write-Host "File not found: $assetFile" -ForegroundColor Red
            return
        }

        $assets = Get-Content -Path $assetFile |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        $results = foreach ($asset in $assets) {

            $asset = $asset.Trim()

            Write-Host "Looking up $asset..." -ForegroundColor Cyan

            $assetInfo = Get-SnipeAssetInfo -AssetTag $asset

            if ($null -eq $assetInfo) {
                Write-Host "  $asset not found." -ForegroundColor Yellow

                # Keep a record in the CSV for assets that weren't found
                [PSCustomObject]@{
                    "Asset Tag"     = $asset
                    "Serial"        = "NOT FOUND"
                    "Model"         = ""
                    "Category"      = ""
                    "Manufacturer"  = ""
                    "Status"        = ""
                    "Location"      = ""
                    "Assigned To"   = ""
                    "Email"         = ""
                    "Condition"     = ""
                    "Working?"      = ""
                }
            }
            else {
                Write-Host "  Found." -ForegroundColor Green
                $assetInfo
            }
        }

        $outputPath = "C:\temp\assetinfobulk.csv"

        # Make sure C:\temp exists
        if (-not (Test-Path "C:\temp")) {
            New-Item -Path "C:\temp" -ItemType Directory | Out-Null
        }

        $results | Export-Csv -Path $outputPath -NoTypeInformation

        if ($?) {
            Write-Host ""
            Write-Host "Results exported to:" -ForegroundColor Yellow
            Write-Host $outputPath -ForegroundColor Yellow
        }
    }


    # ==========================
    # Invalid Option
    # ==========================
    default {
        Write-Host ""
        Write-Host "Invalid option. Please choose 1 or 2." -ForegroundColor Red
    }
}
