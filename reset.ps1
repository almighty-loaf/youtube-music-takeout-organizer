param (
    [Parameter(Mandatory = $true)]
    [string]$MusicPath
)

# Move all files back to the music root
Get-ChildItem -Path $MusicPath -File -Recurse | ForEach-Object {
    # Ensure we don't try to move files already in the root
    if ($_.DirectoryName -ne $MusicPath) {
        Move-Item -Path $_.FullName -Destination $MusicPath -Force
    }
}

# Delete all now-empty subdirectories
Get-ChildItem -Path $MusicPath -Directory | ForEach-Object {
    Remove-Item -Path $_.FullName -Recurse
}