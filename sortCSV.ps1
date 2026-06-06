[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$MusicPath
)

# Allow providing the CSV file directly or inferring it from the music path
if ($MusicPath.EndsWith("music uploads metadata.csv")) { $csvPath = $MusicPath } 
else { $csvPath = Join-Path $MusicPath "music uploads metadata.csv" }

if (-not (Test-Path $csvPath)) { Write-Error "File not found"; exit }

$csvFile = Import-Csv -LiteralPath $csvPath # Let this command finish so that it releases the file lock before the next line writes to it
$csvFile | Sort-Object -Property "Album Title" | Export-Csv -LiteralPath $csvPath -NoTypeInformation