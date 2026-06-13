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
   .\Sort-CSV.ps1 "C:\yourpath\music (library and uploads)\music uploads metadata.csv" -SortBy Album
   ````
### Prep Data
1. Prevent false positives for "Various Artists"
    ````pwsh
    .\Show-ListArtists.ps1 "C:\yourpath\music (library and uploads)\music uploads metadata.csv"
    ````
    - Any names that appear here contain one or more of `,\/&;`, which indicate a list rather than a true album artist.
    - Add genuine names to the `AlbumArtists` array in `Config.ps1`, and those will be treated as ordinary values.
2. Normalize album artists
    ````pwsh
    .\Show-MultiArtistAlbums.ps1 "C:\yourpath\music (library and uploads)\music uploads metadata.csv" -Count 2
    ````
   - Soundtracks and compilations often credit the individual artist for a song rather than the Album Artist, which results in the album getting split across multiple artist folders
   - Any albums that appear here can be forced to use a specific album artist by editing the `OverrideAlbumArtists` dictionary in `Config.ps1`. 

### Organize
7. Run the main script with the following arguments:
   - `MusicPath` - the path to the immediate directory containing the music files
   - `Verbose` - include to show messages whenever a song can't be organized
   - `Debug` - include show album artist names being overridden and files moved (recommend redirecting output to a file in this case via `*>` stream redirector)

    For example:
    ```pwsh
    .\Organize-Music.ps1 -MusicPath "C:\yourpath\music (library and uploads)" -Verbose
    ```
8. Manually organize any remaining unprocessed files.
9. Review the Various Artists folder and reorganize the songs here as necessary.
10. Update file names and metadata if desired. (Mp3Tag, MusicBrainz Picard, etc.)
11. Move the folders to their final destination.
12. ***Highly Recommended*** - Create a proper backup strategy for your music so that you never have to export from YouTube Music again. 😉

## Limitations
- This script can only read file metadata within Windows, which results in more files being skipped when run on Linux or macOS.
- When multiple songs have the same name and duration, it might not be possible to distinguish them. This is most likely for scenarios where song are effectively duplicates, perhaps one from the original album and another from a "Greatest Hits" compilation.
- In rare instances, some song durations provided in the CSV don't match the durations in their respective files. There is a 3 second window to account for this, but any larger discrepancies might result in files being skipped.
  
## Enhancement Opportunities
- Make this script more cross-platform by using `TagLib#` or `ffprobe` to read file metadata
- Add a second pass through the CSV that attempts to handle "stragglers" which couldn't originally be matched, but can now that there is only one viable candidate
- Automatically populate missing file metadata from the CSV

## Requirements
- PowerShell 7+