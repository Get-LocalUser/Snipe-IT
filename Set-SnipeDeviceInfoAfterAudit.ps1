$notes = Read-Host "Enter in what you want for the Notes on each device"

Add-Type -AssemblyName System.Windows.Forms

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

    $assetid = Get-SnipeitAsset -asset_tag $asset | Select-Object id 
    $assetid = [int]$assetid.id

    try {
        $setinfo = Set-SnipeitAsset `
            -id $assetid `
            -status_id 12 `
            -rtd_location_id $null ` # updates both Default Location and Location
            -notes $notes `
            -ErrorAction Continue

        Write-Host "Successfully updated $asset" -ForegroundColor Green

    }
    catch {
        Write-Host "Failed to update $asset`: $($_.Exception.Message)" -ForegroundColor Red
    }

}