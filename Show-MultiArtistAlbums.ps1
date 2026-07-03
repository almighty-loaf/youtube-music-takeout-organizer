param (
    [Parameter(Mandatory = $true)]
    [string]$path,

    [Parameter(Mandatory = $false)]
    [int]$Count = 2
)

. .\Helpers.ps1

$csvPath = Get-CSVFromPath $path
if (-not (Test-Path $csvPath -ErrorAction SilentlyContinue)) { 
    Write-Error "Required file cannot be found: '$csvPath'"
    exit
}

Import-Csv $csvPath | `
    Group-Object -Property "Album Title" | `
    Where-Object { ($_.Group | Select-Object -ExpandProperty "Artist Name 1" -Unique).Count -ge $Count } | `
    Select-Object -ExpandProperty Name
