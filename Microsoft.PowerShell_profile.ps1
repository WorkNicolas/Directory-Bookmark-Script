# --- Directory bookmarks for PowerShell ---
$Global:BookmarkFile = Join-Path $HOME ".dir_bookmarks"

function bookmark {
    param(
        [Parameter(Position = 0)]
        [string]$Arg1,
        [Parameter(Position = 1)]
        [string]$Arg2
    )

    if (-not (Test-Path $Global:BookmarkFile)) {
        New-Item -ItemType File -Path $Global:BookmarkFile -Force | Out-Null
    }

    if (-not $Arg1 -or $Arg1 -in @('-h', '--help')) {
        Write-Output "Usage:"
        Write-Output "  bm --create|-c [dir]     Create bookmark for dir (default: current directory)"
        Write-Output "  bm --jump|-j <title>     Jump to bookmark by title"
        Write-Output "  bm ls                    List bookmark titles"
        Write-Output "  bm rm <title>            Remove bookmark by title"
        return
    }

    # bookmark ls
    if ($Arg1 -eq "ls") {
        $titles = @()
        foreach ($line in Get-Content $Global:BookmarkFile) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line -split '\|', 2
            if ($parts[0]) { $titles += $parts[0] }
        }

        if ($titles.Count -gt 0) {
            # one title per line, like the Bash/zsh versions
            $titles | ForEach-Object { Write-Output $_ }
        }

        return
    }

    # bookmark rm <name>
    if ($Arg1 -eq "rm") {
        $name = $Arg2
        if (-not $name) {
            Write-Host "[ERROR] - missing bookmark name"
            return
        }

        $found = $false
        $newLines = @()

        foreach ($line in Get-Content $Global:BookmarkFile) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line -split '\|', 2
            $title = $parts[0]
            $path  = $parts[1]

            if ($title -eq $name) {
                $found = $true
                continue
            }

            $newLines += "$title|$path"
        }

        # Rewrite file (or clear if no lines left)
        if ($newLines.Count -gt 0) {
            $newLines | Set-Content $Global:BookmarkFile
        } else {
            # keep file existing but empty
            '' | Set-Content $Global:BookmarkFile
        }

        if ($found) {
            Write-Host "[SUCCESS] - $name removed"
        } else {
            Write-Host "[ERROR] - $name doesn't exist"
        }
        return
    }

    # bookmark -c [path] / bookmark --create [path]
    if ($Arg1 -in @('-c', '--create')) {
        $path = if ($Arg2) { $Arg2 } else { (Get-Location).Path }

        if (-not (Test-Path -LiteralPath $path -PathType Container)) {
            Write-Host "[ERROR] - could not resolve directory: $path"
            return
        }

        # Use fully-qualified Resolve-Path to ignore aliases/wrapper functions
        $fullPath = (Microsoft.PowerShell.Management\Resolve-Path -LiteralPath $path).Path

        while ($true) {
            Write-Host -NoNewLine "[Bookmark Title]: "
            $title = Read-Host

            if ($title -match '\s') {
                Write-Host "[ERROR] - bookmark $title has spaces"
                continue
            }

            if (-not $title) {
                continue
            }

            $exists = $false
            foreach ($line in Get-Content $Global:BookmarkFile) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                $parts = $line -split '\|', 2
                if ($parts[0] -eq $title) {
                    $exists = $true
                    break
                }
            }

            if ($exists) {
                Write-Host "[ERROR] - bookmark $title already exists"
                continue
            }

            "$title|$fullPath" | Add-Content $Global:BookmarkFile
            Write-Host "[SUCCESS] - bookmark $title has been created"
            break
        }

        return
    }

    # bookmark -j <title> / bookmark --jump <title>
    if ($Arg1 -in @('-j', '--jump')) {
        $wantedTitle = $Arg2
        if (-not $wantedTitle) {
            Write-Host "[ERROR] - missing bookmark name"
            return
        }

        $dest = $null

        foreach ($line in Get-Content $Global:BookmarkFile) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line -split '\|', 2
            if ($parts[0] -eq $wantedTitle) {
                $dest = $parts[1]
                break
            }
        }

        if (-not $dest) {
            Write-Host "[ERROR] - $wantedTitle doesn't exist"
            return
        }

        if (-not (Test-Path -LiteralPath $dest -PathType Container)) {
            Write-Host "[ERROR] - failed to cd into $dest"
            return
        }

        # Use fully-qualified Set-Location (like builtin cd)
        Microsoft.PowerShell.Management\Set-Location -LiteralPath $dest
        return
    }

    Write-Host "[ERROR] - unknown command: $Arg1"
    Write-Host "Run: bm --help"
    return
}

Set-Alias bm bookmark
