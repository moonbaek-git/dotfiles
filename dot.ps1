# dot.ps1 - install the dotfiles of one app (or all apps) from a single repo.
# Only the folders you ask for are downloaded (git sparse checkout + partial clone).
#
#   .\dot.ps1 install <app...>    download that app's folder and link it into place
#   .\dot.ps1 install all         do it for every app in manifest.txt
#   .\dot.ps1 list                show apps and whether they are installed
#   .\dot.ps1 update              git pull the repo
#   .\dot.ps1 remove <app...>     remove the link (your files stay in the repo)
param(
    [Parameter(Position = 0)][string]$Command,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Apps
)
$ErrorActionPreference = 'Stop'

$RepoUrl  = if ($env:DOTFILES_REPO) { $env:DOTFILES_REPO } else { 'git@github.com:moonbaek-git/dotfiles.git' }
$Dir      = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $HOME '.dotfiles' }
$Manifest = Join-Path $Dir 'manifest.txt'

function Ensure-Repo {
    if (Test-Path (Join-Path $Dir '.git')) { return }
    git clone --depth 1 --filter=blob:none --sparse $RepoUrl $Dir
    if ($LASTEXITCODE -ne 0) { throw 'git clone failed' }
}

# manifest lines: app | linux target | windows target
function Get-Entries {
    $lines = Get-Content $Manifest | Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') }
    foreach ($line in $lines) {
        $p = @($line -split '\|' | ForEach-Object { $_.Trim() })
        if ($p.Count -ge 3) {
            [pscustomobject]@{ App = $p[0]; Target = ($p[2] -replace '^~', $HOME) }
        }
    }
}

function Test-Linked([string]$Target, [string]$Source) {
    $item = Get-Item $Target -Force -ErrorAction SilentlyContinue
    if (-not $item -or -not $item.LinkType) { return $false }
    $resolved = (Resolve-Path $Source).Path
    return (@($item.Target) -contains $resolved)
}

function Install-App([string]$Name) {
    $entry = Get-Entries | Where-Object { $_.App -eq $Name } | Select-Object -First 1
    if (-not $entry) { throw "unknown app '$Name' (see: dot.ps1 list)" }

    git -C $Dir sparse-checkout add $Name
    if ($LASTEXITCODE -ne 0) { throw 'git sparse-checkout failed' }

    $src = Join-Path $Dir $Name
    if (-not (Test-Path $src)) { throw "folder '$Name' not found in the repo" }
    $target = $entry.Target

    if (Test-Linked $target $src) { Write-Host "${Name}: already linked"; return }

    if (Test-Path $target) {
        $bak = "$target.bak-" + (Get-Date -Format 'yyyyMMddHHmmss')
        Move-Item $target $bak
        Write-Host "${Name}: existing config moved to $bak"
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    # A junction is a folder link that needs no admin rights or Developer Mode.
    New-Item -ItemType Junction -Path $target -Value $src | Out-Null
    Write-Host "${Name}: $target -> $src"
}

function Remove-App([string]$Name) {
    $entry = Get-Entries | Where-Object { $_.App -eq $Name } | Select-Object -First 1
    if (-not $entry) { throw "unknown app '$Name'" }
    if (Test-Linked $entry.Target (Join-Path $Dir $Name)) {
        [System.IO.Directory]::Delete($entry.Target)   # removes the link only, not the files
        Write-Host "${Name}: link removed"
    } else { Write-Host "${Name}: not linked" }
}

switch ($Command) {
    'install' {
        if (-not $Apps) { throw 'usage: dot.ps1 install <app...|all>' }
        Ensure-Repo
        if ($Apps[0] -eq 'all') { $Apps = @(Get-Entries | ForEach-Object { $_.App }) }
        foreach ($a in $Apps) { Install-App $a }
    }
    'remove' {
        if (-not $Apps) { throw 'usage: dot.ps1 remove <app...>' }
        foreach ($a in $Apps) { Remove-App $a }
    }
    'update' { git -C $Dir pull --ff-only }
    'list' {
        foreach ($e in Get-Entries) {
            $mark = if (Test-Linked $e.Target (Join-Path $Dir $e.App)) { '[x]' } else { '[ ]' }
            Write-Host "$mark $($e.App)  ($($e.Target))"
        }
    }
    default { Write-Host 'usage: dot.ps1 install <app...|all> | remove <app...> | update | list' }
}
