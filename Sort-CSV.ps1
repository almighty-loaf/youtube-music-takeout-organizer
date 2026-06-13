param (
    [Parameter(Mandatory = $true)]
    [string]$MusicPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Album", "Artist")]
    [string]$SortBy = "Album"
)

. .\Helpers.ps1

$csvPath = Get-CSVFromPath $MusicPath
if (-not (Test-Path $csvPath -ErrorAction SilentlyContinue)) { Write-Error "Required file cannot be found: '$csvPath'"; exit }

$sortProperty = if ($SortBy -eq "Album") { "Album Title" } else { "Artist Name 1" }

$csvFile = Import-Csv -LiteralPath $csvPath # Let this command finish so that it releases the file lock before the next line writes to it
$csvFile | Sort-Object -Property $sortProperty | Export-Csv -LiteralPath $csvPath -NoTypeInformation -UseQuotes AsNeeded