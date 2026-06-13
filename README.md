# YouTube Music Takeout Organizer
*This utility organizes the raw dump of YouTube Music Takeout files into a nested hierarchy of Album Artist, Album, and Song*

## Problem
If you uploaded your personal music files to YouTube Music and have now downloaded them through Google Takeout, you will have noticed that a ton of file metadata is inconsistently missing. In some cases, only clobbered filenames remain (e.g. track numbers have been removed, certain characters are replaced with underscores).

The Takeout data does include a CSV file that contains the list of exported songs, including columns for title, album, artists, and duration. However, it is left to the user to manually reorganize and retag the files.

This is extremely cumbersome when you are dealing with thousands of songs.

## Solution
This PowerShell script will reorganize the files in an `Album Artist > Album > Song` folder hierarchy within the music folder root. Any files that aren't able to be organized will remain at the root for manual processing.

## How It Works
This script parses the CSV one row at a time, determines which file is the best match, and then uses the `Artist Name 1` and `Album Title` columns to move it to the correct destination folder.

When there are multiple songs with the same name, the file metadata will be inspected for comparison with the CSV data. (The song duration is usually enough to identify a particular file, but when artist or album are present, those are required to match as well.)

When the `Artist Name 1` column is a list of contributing artists, it's unclear what the Album Artist should be. These files will be moved into a "Various Artists" folder, but this behavior can be overridden per album.

## Instructions
### Get Started
1. Clone this repository onto your machine.
   ```pwsh
   git clone "https://github.com/almighty-loaf/youtube-music-takeout-organizer.git"
   ```
2. Extract all of the Takeout zip files into a single directory.
3. Identify the folder that contains the music files and `music uploads metadata.csv`. It should be found under<br>`Takeout\YouTube and YouTube Music\music (library and uploads)`.
4. Sort the CSV by album or artist to simplify manual review
   ````pwsh
   .\Sort-CSV.ps1 "C:\yourpath\music (library and uploads)" -SortBy Album
   ````
### Prep Data
1. Identify false positives for "Various Artists" (those that contain any of the characters `,\/&;`)
    1. Run the following pipeline, which will show all values for `Artist 1` that meet this criteria
        ````pwsh
        Import-Csv "C:\yourpath\music (library and uploads)\music uploads metadata.csv" | Group-Object "Artist Name 1" | Where-Object {$_.Name -match '[,\/&;]'} | Select-Object -Property Name
        ````
    2. Some of these names may be false positives if the artist does use a list separator, such as *AC/DC*. In these cases, you can add them to the `AlbumArtists` array in `config.ps1` which will cause them to be treated as ordinary values.
    3. There might be harder-to-detect scenarios where one compilation album has many individual artist names. In these cases, you can override the album artist on a per-album basis.<br>Open `config.ps1` and update the `OverrideAlbumArtists` map. The value on the left is the album name, and the value on the right is the album artist to use.
2. Identify albums that don't have a consistent Album Artist
   1. Soundtracks and compilations often credit the individual artist for a song rather than the Album Artist, resulting in the album getting split across multiple per-artist folders
   2. To identify these, run the following pipeline to show all albums that multiple unique associated artists
      ````pwsh
      # Increase the threshold if you see false positives
      $threshold = 2
      Import-Csv "B:\takeout test\music uploads metadata.csv" | Group-Object -Property "Album Title" | Where-Object { ($_.Group | Select-Object -ExpandProperty "Artist Name 1" -Unique).Count -ge $threshold } | Select-Object -ExpandProperty Name
      ````
   3. You can force any of these albums to use a specific album artist by editing the `OverrideAlbumArtists` dictionary in `config.ps1`. 

### Organize
7. Run the main script with the following arguments:
   - `MusicPath` **(Required)** - the path to the immediate directory containing the music files
   - `Verbose` - show messages whenever a song can't be organized
   - `Debug` - show album artist names being overridden and files moved (recommend redirecting output to a file in this case via `*>` stream redirector)

    For example:
    ```pwsh
    .\Organize-Music.ps1 -MusicPath "C:\yourpath\C:\yourpath\music (library and uploads)" -Verbose
    ```
8. Manually organize any remaining unprocessed files.
9.  Manually organize the Various Artists folder as necessary.
10. Update file names and metadata as necessary. (Mp3Tag, MusicBrainz Picard, etc.)
11. Move the folders to their final destination.
12. ***Highly Recommended*** - Create a proper backup strategy for your music so that you never have to export from YouTube Music again. 😉

## Limitations
- This script can only read file metadata within Windows, which can result in more files being skipped when run on Linux or macOS.
- When multiple songs have the same name and duration, it might not be possible to distinguish them. This is most likely for scenarios where song are effectively duplicates, perhaps one from the original album and another from a "Greatest Hits" compilation.
  - To show all overlapping names, you can run this:
    ```pwsh
    Import-Csv "C:\yourpath\music (library and uploads)\music uploads metadata.csv" | Group-Object "Song Title" | Where-Object { $_.Count -gt 1}
    ```
- There are some instances where song durations in the CSV don't match the duration in their respective files. There is a 3 second window to account for this, but any larger discrepancies might result in files being skipped.
  
## Enhancement Opportunities
- Make this script more cross-platform by using `TagLib#` or `ffprobe` to read file metadata
- Add a second pass through the CSV that attempts to handle "stragglers" which couldn't originally be matched, but can now that there is only one viable candidate
- Automatically populate missing file metadata from the CSV
- Automatically detect cases where a large portion of 
  - Or preprocess step that looks for albums with more than 1 listed artist, and automatic/manual update to set album artist
- Detect multi-artist compilation/soundtrack albums where each individual song has a single artist, and group them under one artist folder