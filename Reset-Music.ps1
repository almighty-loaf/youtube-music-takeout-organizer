param (
    [Parameter(Mandatory = $true)]
    [string]$MusicPath
)

# Move all files back to the music root
Get-ChildItem -LiteralPath $MusicPath -File -Recurse | ForEach-Object {
    # Ensure we don't try to move files already in the root
    if ($_.DirectoryName -ne $MusicPath) {
        Move-Item -LiteralPath $_.FullName -Destination $MusicPath -Force
    }
}

# Delete all now-empty subdirectories
Get-ChildItem -LiteralPath $MusicPath -Directory | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Recurse
}