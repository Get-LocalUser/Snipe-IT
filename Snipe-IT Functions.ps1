function New-SnipeITConnection {
    param (
        [string]$XMLPath = "$env:USERPROFILE\Downloads\snipecred.xml"
    )

    Connect-SnipeitPS -siteCred (Import-Clixml $XMLPath)
    if ($?) {
        Write-Host "`nConnected to Snipe-IT`n" -ForegroundColor DarkGreen
    }
}


function Get-SnipeUserDevices {
    param (
        [string]$SingleUser,
        [string]$MultipleUsers
    )

    $choice = $null

    # Only show the menu if no parameters were supplied
    if (-not $SingleUser -and -not $MultipleUsers) {
        Write-Host "[1] Single user lookup"
        Write-Host "[2] Multiple user lookup"
        $choice = Read-Host "Enter selection"
    }

    # Prompt ONLY if the value wasn't supplied as a parameter
    if ($choice -eq 1 -and -not $SingleUser) {
        $SingleUser = Read-Host "Enter UPN"
    }
    if ($choice -eq 2 -and -not $MultipleUsers) {
        $MultipleUsers = Read-Host "Enter path to file containing UPN's"
    }

    if ($SingleUser) {
        $singleuserassets = Get-SnipeitAsset -search $SingleUser

        if ($singleuserassets) {
            $singleuserassets | Select-Object `
                @{Name='User';      Expression={$_.assigned_to.name}},
                @{Name='Model';     Expression={$_.model.name}},
                @{Name='Asset Tag'; Expression={$_.asset_tag}},
                @{Name='Serial';    Expression={$_.serial}}
        }
        else {
            Write-Host "No assets found for $SingleUser" -ForegroundColor Yellow
        }
    }

    if ($MultipleUsers) {
        if (-not (Test-Path -Path $MultipleUsers)) {
            Write-Host "File not found: $MultipleUsers" -ForegroundColor Red
            return
        }

        $users  = Get-Content -Path $MultipleUsers | Where-Object { $_.Trim() }
        $assets = Get-SnipeitAsset -all

        $results = foreach ($user in $users) {
            $user = $user.Trim()

            $iduser = (Get-SnipeitUser -search $user | Select-Object -First 1).Id

            $userAssets = if ($iduser) {
                $assets | Where-Object { $_.assigned_to.id -eq $iduser }
            }

            if ($userAssets) {
                $userAssets | Select-Object `
                    @{Name='User';      Expression={$_.assigned_to.name}},
                    @{Name='Model';     Expression={$_.model.name}},
                    @{Name='Asset Tag'; Expression={$_.asset_tag}},
                    @{Name='Serial';    Expression={$_.serial}}
            }
            else {
                [PSCustomObject]@{
                    User        = $user
                    Model       = 'NO ASSETS'
                    'Asset Tag' = 'NO ASSETS'
                    Serial      = 'NO ASSETS'
                }
            }
        }

        $exportPath = "$env:USERPROFILE\Downloads\SnipeIT_UserAssets_Export.csv"
        try {
            $results | Export-Csv -Path $exportPath -NoTypeInformation -ErrorAction Stop
            Write-Host "Results exported to $exportPath" -ForegroundColor Yellow
        }
        catch {
            Write-Host "Export failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}


function Get-SnipeAssetInfo {
    param (
        [string]$AssetTag,
        [string]$File
    )

    $choice = $null

    # Only show the menu if no parameters were supplied
    if (-not $AssetTag -and -not $File) {
        Write-Host "[1] Single device lookup"
        Write-Host "[2] Multiple device lookup"
        $choice = Read-Host "Enter selection"
    }

    # Prompt ONLY if the value wasn't supplied as a parameter
    if ($choice -eq 1 -and -not $AssetTag) {
        $AssetTag = Read-Host "Enter Asset Tag"
    }

    if ($choice -eq 2 -and -not $File) {

        # ==========================
        # Bulk Asset Lookup
        # ==========================

        # Open file selection dialog
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

            $asset = $asset.Trim()

            Write-Host "Looking up $asset..." -ForegroundColor Cyan

            $assetInfo = Get-SnipeAssetInfo -AssetTag $asset

            if ($null -eq $assetInfo) {
                Write-Host "  $asset not found." -ForegroundColor Yellow

                [PSCustomObject]@{
                    "Asset Tag"     = $asset
                    "Serial"        = "NOT FOUND"
                    "IMEI"          = ""
                    "IMEI 2"        = ""
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
        $result = Get-SnipeitAsset -serial $AssetTag -ErrorAction SilentlyContinue
    }

    if ($null -eq $result) {
        Write-Host "$AssetTag not found." -ForegroundColor Yellow
        return $null
    }

    [PSCustomObject]@{
        "Asset Tag"     = $result.asset_tag
        "Serial"        = $result.serial
        "IMEI"          = if ([string]::IsNullOrWhiteSpace($result.custom_fields.IMEI.value)) { "N/A" } else { $result.custom_fields.IMEI.value }
        "IMEI 2"        = if ([string]::IsNullOrWhiteSpace($result.custom_fields."IMEI 2".value)) { "N/A" } else { $result.custom_fields."IMEI 2".value }
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


function Get-AllSnipeDisabledUsers {

    $disabledusers = Get-SnipeitUser -all | Where-Object { $_.activated -eq $false }

    Write-Host "There are $($disabledusers.Count) disabled users." -ForegroundColor Magenta
    Write-Host ""

    $displayList = @()
    $psc = 1

    # Build a simplified list of users for display
    foreach ($user in $disabledusers) {
        $row = [PSCustomObject]@{
            "Instance #"       = $psc
            "Snipe ID"         = $user.id   # Snipe-IT's internal user ID
            Name               = $user.name
            Department         = $user.department.name
            Manager            = $user.manager.name
            "# of Assets"      = $user.assets_count
            "# of Accessories" = $user.accessories_count
            Zeroed             = ($user.assets_count -eq 0 -and $user.accessories_count -eq 0)
            Notes              = $user.notes
        }
        $displayList += $row
        $psc++
    }

    # Sort selection
    do {
        $sortOptions = @(
            "Name"
            "Manager"
            "Assets"
            "Accessories"
            "Zeroed"
            "Notes"
            "Instance #"
            "Snipe ID"
        )

        $sortOptions | ForEach-Object { $i = 1 } { "$i. $_"; $i++ }

        $chosenoption = $sortOptions[(Read-Host "Select a sort option") - 1]

        Write-Host "You selected: $chosenoption"

        switch ($chosenoption) {
            "name"        { $displayList | Sort-Object Name | Format-Table; $valid = $true }
            "manager"     { $displayList | Sort-Object Manager | Format-Table; $valid = $true }
            "assets"      { $displayList | Sort-Object "# of Assets" | Format-Table; $valid = $true }
            "accessories" { $displayList | Sort-Object "# of Accessories" | Format-Table; $valid = $true }
            "zeroed"      { $displayList | Sort-Object "Zeroed" | Format-Table; $valid = $true }
            "notes"       { $displayList | Sort-Object Notes | Format-Table; $valid = $true }
            "instance #"  { $displayList | Sort-Object "Instance #" | Format-Table; $valid = $true }
            "snipe id"    { $displayList | Sort-Object "Snipe ID" | Format-Table; $valid = $true }
            default {
                Write-Host "Invalid sort option. Try again." -ForegroundColor Red
                $valid = $false
            }
        }
    } while (-not $valid)

    # Per-user lookup loop
    do {

        # Get the instance number of the user to expand
        do {
            $input = Read-Host "Type Instance # to view assets/accessories"
        } while ($input -notmatch '^\d+$')

        [int]$question2 = $input

        Write-Host ""

        # Find the selected user from the displayed list
        $selectedUser = $displayList | Where-Object {
            $_.'Instance #' -eq $question2
        }

        if ($selectedUser) {
            # Get assets assigned to the selected user
            $assets = Get-SnipeitAsset -user_id $selectedUser.'Snipe ID'

            $userdevices = foreach ($asset in $assets) {
                [PSCustomObject]@{
                    "Asset Tag"     = $asset.asset_tag
                    "Serial Number" = $asset.serial
                    Model           = $asset.model.name
                    Category        = $asset.category.name
                }
            }

            # Get accessories assigned to the selected user
            $useraccessories = Get-SnipeitAccessory -user_id $selectedUser.'Snipe ID'
        }

        $userdevices | Format-Table -AutoSize

        $useraccessories |
            Group-Object -Property Name |
            ForEach-Object {
                [PSCustomObject]@{
                    Quantity            = $_.Count
                    "Accessory Item(s)" = $_.Name
                }
            } | Format-Table -AutoSize

        do {
            $emailquestion = Read-Host "Write email? [Y/N]"
            Write-Host ""

            if ($emailquestion -in @("Y", "y")) {

                # Due date: 5 business days from today
                $date = Get-Date

                for ($i = 0; $i -lt 5; $i++) {
                    $date = $date.AddDays(1)

                    while ($date.DayOfWeek -eq "Saturday" -or $date.DayOfWeek -eq "Sunday") {
                        $date = $date.AddDays(1)
                    }
                }

                $date = $date.ToShortDateString()

                $managerFirstName = ($selectedUser.Manager -split ',')[1].Trim()

                Write-Host "============== Start of EMail ==============" -ForegroundColor Yellow

                $email = @"
Hi $($managerFirstName),

I'm reaching out regarding $($selectedUser.Name) who was recently terminated. According to our records, $($selectedUser.Name) has the IT equipment listed below that needs to be returned to the IT HelpDesk at OPS.

You may return the items via interoffice mail or drop them off at the HelpDesk. Please return the items within business 5 days as per the Departing Employee Procedures Policy no later than $date.

Please let me know if you have any questions.
"@

                Write-Host "`n$email"
                Write-Host "Thanks for your time!"
                Write-Host ""

                $userdevices | Format-Table -AutoSize

                $useraccessories |
                    Group-Object -Property Name |
                    ForEach-Object {
                        [PSCustomObject]@{
                            Quantity            = $_.Count
                            "Accessory Item(s)" = $_.Name
                        }
                    } | Format-Table -AutoSize

                Write-Host "============== End of EMail ==============" -ForegroundColor Yellow

                $validEmailChoice = $true
            }
            elseif ($emailquestion -in @("N", "n")) {
                $validEmailChoice = $true
                Write-Host "Email skipped."
            }
            else {
                Write-Host "Invalid option. Please enter Y or N." -ForegroundColor Red
                $validEmailChoice = $false
            }

            $note = Read-Host "Enter notes for user (leave blank to skip)"

            if ($note) {
                Set-SnipeitUser -id $selectedUser.'Snipe ID' -notes $note -Confirm | Out-Null
            }

        } while (-not $validEmailChoice)

        $Check = Read-Host "Check another user? [Y/N]"

    } while ($Check -eq "Y")
}


function Get-SnipeAssetActivity {
    param (
        [string]$AssetTag,
        [string]$File
    )

    $choice = $null

    # Only show the menu if no parameters were supplied
    if (-not $AssetTag -and -not $File) {
        Write-Host "[1] Single device activity search"
        Write-Host "[2] Multiple device activity search"
        $choice = Read-Host "Enter selection"
    }

    # Prompt ONLY if the value wasn't supplied as a parameter
    if ($choice -eq 1 -and -not $AssetTag) {
        $AssetTag = Read-Host "Enter Asset Tag"
        $asset = Get-SnipeitAsset -asset_tag $AssetTag

        Get-SnipeitActivity -item_type 'asset' -item_id $asset.Id |
        Select-Object `
            @{Name='Device Name'; Expression={$_.item.name}},
            @{Name='Created At'; Expression={$_.created_at.datetime}},
            @{Name='Action Type'; Expression={$_.action_type}},
            @{Name='Admin'; Expression={$_.admin.name}},
            @{Name='Target'; Expression={$_.target.name}},
            @{Name='Note'; Expression={$_.note}},
            @{Name='Old Location'; Expression={$_.log_meta."current location".old -replace '^\[id:\s*\d+\]\s*', ''}},
            @{Name='New Location'; Expression={$_.log_meta."current location".new -replace '^\[id:\s*\d+\]\s*', ''}},
            @{Name='Old Status'; Expression={$_.log_meta."status label".old -replace '^\[id:\s*\d+\]\s*', ''}},
            @{Name='New Status'; Expression={$_.log_meta."status label".new -replace '^\[id:\s*\d+\]\s*', ''}} |
        Format-Table -AutoSize
    }


    if ($choice -eq 2 -and -not $File) {

        # Open file selection dialog
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

            $asset = $asset.Trim()

            Write-Host "Looking up $asset..." -ForegroundColor Cyan

            $asset = Get-SnipeitAsset -asset_tag $asset

            Get-SnipeitActivity -item_type 'asset' -item_id $asset.Id |
                Select-Object `
                    @{Name='Device Name'; Expression={$_.item.name}},
                    @{Name='Created At'; Expression={$_.created_at.datetime}},
                    @{Name='Action Type'; Expression={$_.action_type}},
                    @{Name='Admin'; Expression={$_.admin.name}},
                    @{Name='Target'; Expression={$_.target.name}},
                    @{Name='Note'; Expression={$_.note}},
                    @{Name='Old Location'; Expression={$_.log_meta."current location".old -replace '^\[id:\s*\d+\]\s*', ''}},
                    @{Name='New Location'; Expression={$_.log_meta."current location".new -replace '^\[id:\s*\d+\]\s*', ''}},
                    @{Name='Old Status'; Expression={$_.log_meta."status label".old -replace '^\[id:\s*\d+\]\s*', ''}},
                    @{Name='New Status'; Expression={$_.log_meta."status label".new -replace '^\[id:\s*\d+\]\s*', ''}}
        }

        $outputPath = "$env:USERPROFILE\Downloads\AssetActivtiyReport.csv"

        $results | Export-Csv -Path $outputPath -NoTypeInformation

        if ($?) {
            Write-Host ""
            Write-Host "Results exported to:" -ForegroundColor Yellow
            Write-Host $outputPath -ForegroundColor Yellow
        }

        return
    } 
}


function Set-PostNewHireDeployments {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Username
    )
    
    $User = Get-SnipeitUser -username $Username

    $Assets = Get-SnipeitAsset -user_id $User.id

    $location = Get-SnipeitLocation -id 4

    foreach ($Asset in $Assets) {
        if ($PSCmdlet.ShouldProcess($Asset.asset_tag, "Set status to Deployed and location to $($location.name)")) {
            Set-SnipeitAsset -id $Asset.id -status_id 4 -rtd_location_id 4 | Out-Null
        }
        $check = Get-SnipeitAsset -id $Asset.id
        if ($check.status.id -eq 4 -and $check.rtd_location.id -eq 4) {
            Write-Host "- '$($Asset.asset_tag)' Updated with Status '$($Asset.status.name)' and Location '$($location.name)' for user '$($Username)'" -ForegroundColor Green
        }
    }
}


function SnipeScripts {
    
    New-SnipeITConnection

    do {

        Write-Host "  ┌─[ ▄︻╦芫≡══── ⌯⁍ ]───────────────────────────────────┐" -ForegroundColor Red
        Write-Host "  │                                                      │" -ForegroundColor Green
        Write-Host "  │   [01]  View User Devices                            │" -ForegroundColor Green
        Write-Host "  │   [02]  View Asset Information                       │" -ForegroundColor Green
        Write-Host "  │   [03]  View Disabled Accounts                       │" -ForegroundColor Green
        Write-Host "  │   [04]  View Asset Activity History                  │" -ForegroundColor Green
        Write-Host "  │   [05]  Update Asset Status Post Deployment          │" -ForegroundColor Green
        Write-Host "  │   [06]  Exit Application                             │" -ForegroundColor Green
        Write-Host "  │                                                      │" -ForegroundColor Green
        Write-Host "  └──────────────────────────────────────────────────────┘" -ForegroundColor Red
        Write-Host ""


        $choice = Read-Host "Select an option "

        switch ($choice) {
            "1" { Get-SnipeUserDevices | Out-Host }
            "2" { Get-SnipeAssetInfo }
            "3" { Get-AllSnipeDisabledUsers }
            "4" { Get-SnipeAssetActivity }
            "5" { Set-PostNewHireDeployments }
            "6" { Exit }
            default { Write-Host "Invalid choice" -ForegroundColor Red }
        }

        if ($choice -ne "6") {
            Write-Host ""
            Read-Host "Press ENTER to return to the main menu"
            Clear-Host
        }
    } while (
        $choice -ne "6"
    )
}


SnipeScripts