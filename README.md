# YouTube Music Takeout Organizer

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

## How to Use 
1. Extract all of the zip files into a single directory.
2. Review the `music uploads metadata.csv` file and make sure it has the values you generally expect. It should be found under<br>`Takeout\YouTube and YouTube Music\music (library and uploads)`.
3. Add manual overrides for Album Artist as necessary
    1. Pay particular attention to the values in the `Artist 1` column.<br>To prevent artists named with `,\/&;` from being treated as "Various Artists", open `config.ps1` and add them to the `AlbumArtists` array.
    2. To find these, you can run this pipeline:
        ````pwsh
        Import-Csv "yourpath\music uploads metadata.csv" | Group-Object "Artist Name 1" | Where-Object {$_.Name -match '[,\/&;]'}
        ````
    3. There might be harder-to-detect scenarios where one compilation album has many individual artist names. In these cases, you can override the album artist on a per-album basis.<br>Open `config.ps1` and update the `OverrideAlbumArtists` map. The value on the left is the album name, and the value on the right is the album artist to use.
4. Invoke the script from the terminal with the following arguments:
   - `MusicPath` **(Required)** - the path to the immediate directory containing the music files
   - `Verbose` - show messages whenever a song can't be organized
   - `Debug` - show album artist names being overridden and files moved (recommend redirecting output to a file in this case via `*>` stream redirector)

    For example:
    ```pwsh
    .\main.ps1 -MusicPath "C:\somepath\music (library and uploads)" -Verbose
    ```
5. Spot-check the folders to make sure that the artists and albums were identified correctly, and make any necessary adjustments.
6. Manually organize any remaining unprocessed files.
7. Manually organize the Various Artists folder as necessary.
8. Update file names and metadata as necessary. (Mp3Tag, MusicBrainz Picard, etc.)
9. Move the folders to their final destination.
10. ***Highly Recommended*** - Create a proper backup strategy for your music so that you never have to export from YouTube Music again. 😉

## Limitations
- This script can only read file metadata within Windows, which can result in more files being skipped when run on Linux or macOS.
- When multiple songs have the same name and duration, it might not be possible to distinguish them. This is most likely for scenarios where song are effectively duplicates, perhaps one from the original album and another from a "Greatest Hits" compilation.
  - To show all overlapping names, you can run this:
    ```pwsh
    Import-Csv "yourpath\music uploads metadata.csv" | Group-Object "Song Title" | Where-Object { $_.Count -gt 1}
    ```
- There are some instances where song durations in the CSV don't match the duration in their respective files. There is a 3 second window to account for this, but any larger discrepancies might result in files being skipped.
  
## Enhancement Opportunities
- Make this script more cross-platform by using `TagLib#` or `ffprobe` to read file metadata
- Add a second pass through the CSV that attempts to handle "stragglers" which couldn't originally be matched, but can now that there is only one viable candidate
- Automatically populate missing file metadata from the CSV
- Automatically detect cases where a large portion of 
  - Or preprocess step that looks for albums with more than 1 listed artist, and automatic/manual update to set album artist
- Detect multi-artist compilation/soundtrack albums where each individual song has a single artist, and group them under one artist folder