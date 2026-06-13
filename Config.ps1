#############################################
# CONFIGURATION
#############################################

# This utility only cares about Album Artists since that's how it groups the albums.
# However, the "Artist Name 1" column of the CSV is often not the album artist, which
# can result in each listed artist getting their own folder and a slice of the album.


# In some cases, "Artist Name 1" is a set of contributing artists, in the form of
# "Name1, Name2" or "Name1 / Name2". For this reason, any artist names that contain
# any of ,;/& will be grouped under "Various Artists" by default.
#
# Artists listed here will be treated as Album Artists, even if they contain those
# characters.
Set-Variable -Name AlbumArtists -Option constant -Value @(
    # "<Album Artist>",
    "AC/DC",
    "Earth, Wind & Fire"
    # Add yours here (no trailing comma on the last item)
)

# In some cases, like compilation albums, each song in an album may have a separate
# contributing artist.
# Album Titles listed here will always use the provided artist name 
Set-Variable -Name OverrideAlbumArtists -Option constant -Value @{
    # "<Album Title>" = "<Album Artist>";
    "Super Smash Bros. for Nintendo 3DS/Wii U" = "Nintendo";
    # Add yours here
}