Add-Type -AssemblyName System.Windows.Forms

function Get-SnipeAssetInfo {
    param (
        [string]$AssetTag,
        [switch]$File
    )

    # ==========================
    # Bulk Lookup
    # ==========================
    if ($File) {

        # Open file selection dialog
        $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $fileDialog.Title = "Select Asset Tag File"
        $fileDialog.Filter = "Text Files (*.txt)|*.txt|CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
        $fileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
        $fileDialog.Multiselect = $false

        $dialogResult = $fileDialog.ShowDialog()

        # User clicked Cancel
        if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
            Write-Host "File selection cancelled." -ForegroundColor Yellow
            return
        }

        $assetFile = $fileDialog.FileName

        Write-Host ""
        Write-Host "Selected file: $assetFile" -ForegroundColor Cyan
        Write-Host ""

        $assets = Get-Content -Path $assetFile |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        $results = foreach ($asset in $assets) {

            $asset = $asset.Trim()

            Write-Host "Looking up $asset..." -ForegroundColor Cyan

            $assetInfo = Get-SnipeAssetInfo -AssetTag $asset

            if ($null -eq $assetInfo) {
                Write-Host "  $asset not found." -ForegroundColor Yellow

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

        # Make sure C:\temp exists
        if (-not (Test-Path "C:\temp")) {
            New-Item -Path "C:\temp" -ItemType Directory | Out-Null
        }

        $outputPath = "C:\temp\assetinfobulk.csv"

        $results | Export-Csv -Path $outputPath -NoTypeInformation

        if ($?) {
            Write-Host ""
            Write-Host "Results exported to:" -ForegroundColor Yellow
            Write-Host $outputPath -ForegroundColor Yellow
        }

        return
    }


    # ==========================
    # Single Asset Lookup
    # ==========================

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
