$disabledusers = Get-SnipeitUser -all | Where-Object {$_.activated -eq $false}

Write-Host "There are"$($disabledusers).count"disabled users." -ForegroundColor Magenta

$displayList = @()

Write-Host ""
$psc = 1

# Build a simplified list of users for display
foreach ($user in $disabledusers) {
    $row = [PSCustomObject]@{
        "Instance #"        = $psc
        "Snipe ID"          = $user.id # Snipe-IT's internal user ID
        Name                = $user.name
        Department          = $user.department.name
        Manager             = $user.manager.name
        "# of Assets"       = $user.assets_count
        "# of Accessories"  = $user.accessories_count
        "Zeroed"            = if ($user.assets_count -eq 0 -and $user.accessories_count -eq 0) { $true } else { $false }
        Notes               = $user.notes
    }
    $displayList += $row
    $psc++
}

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

    Write-Host "You selected: $chosenOption"

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


do {

    # Get the instance number of the user to expand
    do {
        $input = Read-Host "Type Instance # to view assets/accessories"
    } while ($input -notmatch '^\d+$')

    [int]$question2 = $input

    Write-Host ""

    # Find the selected user from the displayed list
    $selectedUser = $displayList | Where-Object {
        $_.'Instance #' -eq [int]$question2
    }

    # Get and display assets assigned to the selected user
    if ($selectedUser) {
        $assets = Get-SnipeitAsset -user_id $selectedUser.'Snipe ID'

        $userdevices = foreach ($asset in $assets) {
            [PSCustomObject]@{
                "Asset Tag"     = $asset.asset_tag
                "Serial Number" = $asset.serial
                Model           = $asset.model.name
                Category        = $asset.category.name
            } 
        }

        # Get and display accessories assigned to the selected user
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

    $note = Read-Host "Enter notes for user (leave blank to skip)"

    if ($note) {
        Set-SnipeitUser -id $selectedUser.'Snipe ID' -notes $note -Confirm
    }

    do {
        $emailquestion = Read-Host "Write email? [Y/N]"

        if ($emailquestion -in @("Y", "y")) {
        
            $date = (Get-Date)

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

} while (-not $validEmailChoice)

    $Check = Read-Host "Check another user? [Y/N]"

} while (
    $Check -eq "Y"
)