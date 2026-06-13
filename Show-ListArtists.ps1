param(
    [Parameter(Mandatory=$true)]
    [string]$path
)

. .\Helpers.ps1

$path = Get-CSVFromPath $path

Import-Csv $path | `
    Group-Object "Artist Name 1" | `
    Where-Object { $_.Name -match (Get-ArtistListDelimiter-Regex) } | `
    Select-Object -Property Name