#############################################
# HELPER FUNCTIONS
#############################################

# Function to read MP3 metadata properties
# Only works for Windows since it relies on Shell.Application COM object, but could be
# extended to support other OSes by using a different method (e.g. TagLib# or ffprobe)
# superuser.com/questions/704575
# stackoverflow.com/questions/22382010/what-options-are-available-for-shell32-folder-getdetailsof
function Get-FileMetadata {
    param ([string]$filePath)

    # $shell is set in main script

    if (!$shell) { 
        $title = ""
        $album = ""
        $albumArtist = ""
        $duration = ""
    }
    else {
        $folder = $shell.Namespace((Split-Path $filePath))
        $file = $folder.ParseName((Split-Path $filePath -Leaf))

        # Standard property indices for Windows
        $title = $folder.GetDetailsOf($file, 21)
        $album = $folder.GetDetailsOf($file, 14)
        $albumArtist = $folder.GetDetailsOf($file, 13)
        $duration = $folder.GetDetailsOf($file, 27)
    }
    
    return [PSCustomObject]@{
        Title          = $title
        Album          = $album
        AlbumArtist    = $albumArtist
        DurationString = $duration
    }
}

# Function to parse "XhYmZs" format (e.g., "1h20s", "3m40s") to seconds
# stackoverflow.com/questions/75834505
function Convert-CsvDurationToSeconds {
    param ([string]$durationString)

    if ([string]::IsNullOrEmpty($DurationString)) {
        return $null
    }

    # Regex allows optional h, m, s segments
    # Could use [timespan]::ParseExact but then I have to enumerate every permutation of "hh:mm:ss", "mm:ss", "ss" etc.
    if ($durationString -match "^((?<h>\d+)h)?((?<m>\d+)m)?((?<s>\d+(?:\.\d+)?)s)?$") {
        $totalSeconds = 0
        if ($Matches.h) { $totalSeconds += [int]$Matches.h * 3600 }
        if ($Matches.m) { $totalSeconds += [int]$Matches.m * 60 }
        if ($Matches.s) { $totalSeconds += [double]$Matches.s }
        return $totalSeconds
    }
    return $null
}

# Function to parse standard shell duration (mm:ss or hh:mm:ss) to seconds
function Convert-ShellDurationToSeconds {
    param ([string]$durationString)
    if (-not $durationString) { return $null }

    $parts = $durationString.Split(':')
    if ($parts.Count -eq 2) {
        return ([int]$parts[0] * 60) + [double]$parts[1]
    }
    elseif ($parts.Count -eq 3) {
        return ([int]$parts[0] * 3600) + ([int]$parts[1] * 60) + [double]$parts[2]
    }
    # assume it's just seconds if there's only one part
    return [int]$durationString
}

# Regex pattern that represent characters that YTM replaces with underscores in file names
# e.g. song title "Who can it be now?" is "Who can it be now_.mp3"
# Hardcode to the Windows limitations since that's what the source data abides by
function UnderscoreCharsRegex {
    '[\\/:*?"''<>|]'
}

# Replaces invalid characters in file names with underscores
function ConvertTo-SafeFileName {
    param ([string]$name)    
    return ($name -replace (UnderscoreCharsRegex), '_')
}

# Replaces invalid characters in folder names with underscores
# Also removes trailing dots and spaces
function ConvertTo-SafeFolderName {
    param ([string]$name)    
    if ($IsWindows) { $name = $name.TrimEnd('.', ' ') }
    return ($name -replace (UnderscoreCharsRegex), '_')
}

# Calculates the number of times each song title appears
# The count is saved in a title->count map using a safe title
function Get-SafeTitleCountMap {
    param ([array]$csvData)

    $map = @{}
    foreach ($row in $csvData) {
        $safeSongTitle = ConvertTo-SafeFileName $row.'Song Title'

        if (!$safeSongTitle) { continue }
        $map[$safeSongTitle] = $map[$safeSongTitle] + 1
    }
    return $map
}

# Function to check if an artist name contains special characters that would require manual fixing
function Test-ArtistNameMightBeList {
    param ([string]$artistName)
    return ($artistName -match "[,\/&;]")
}