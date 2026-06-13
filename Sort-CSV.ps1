[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$MusicPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Album", "Artist")]
    [string]$SortBy = "Album"
)

# Allow providing the CSV file directly or inferring it from the music path
if ((Split-Path $MusicPath -Leaf) -eq "music uploads metadata.csv") { $csvPath = $MusicPath } 
else { $csvPath = Join-Path $MusicPath "music uploads metadata.csv" }

if (-not (Test-Path $csvPath)) { Write-Error "File not found"; exit }

$sortProperty = if ($SortBy -eq "Album") { "Album Title" } else { "Artist Name 1" }

$csvFile = Import-Csv -LiteralPath $csvPath # Let this command finish so that it releases the file lock before the next line writes to it
$csvFile | Sort-Object -Property $sortProperty | Export-Csv -LiteralPath $csvPath -NoTypeInformation -UseQuotes AsNeeded