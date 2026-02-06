# ![App Icon](Assets/icon-64.png) Musify
Musify is a fork of the Amperfy project with adjustments for my personal needs. I want to thank BLeeEZ for the awesome work that Amperfy represents. My modifications to Amperfy will probably not be liked by most Amperfy users as I have even removed features/settings that I personally do not need. I am a big advocate of a simple UI and provide a minimal number of settings options.
I do not implement pull requests - please support the Amperfy project if you want features to be added. I will include Amperfy updates in Musify from time to time though.

### This is a list of changes I made to Amperfy:

- Changed the app icon to be more self explanatory of the app-type
- Slight modifications of the dark theme (use 95% black and 95% white instead of 100% black/white)
- Show star ratings in song lists (can be controlled by a setting)
- Show a star rating and favorite setting element in the currently-playing view (can be controlled by a setting)
- Show a Song Info view with details about the currently played song by clicking (i) button
- Show lyrics by just clicking on the album art in currently-playing view
- Show the total song duration in currently-playing view
- Redesign of the lyrics view and removed the 'Lyrics Smooth Scrolling' setting (enabled by default)
- Removed the User Queue feature (there is now only one queue)
- Only show one settings button "..." in currently-playing view
  - Redesign of context menu
  - Removed 'Download' (can be done from Song Info view)
  - Removed Visualizer (Visualizer is slow and not impressive so hide it for now)
  - Removed 'Show Lyrics' (lyrics can be opened by click on album art)
  - Removed 'Favorite' (can be done at main view)
  - Removed 'Rating:' (can be done at main view)
  - Removed Copy ID to Clipboard' (can be done in Song Info view)
  - Removed the volume button from currently playing view (feature redundant with airplay button)
  - Renamed context queue to just queue
- Show a 'Preamp' setting when ReplayGain is enabled. As ReplayGain will most often reduce the volume, this value can be used to have a general offset value and keep music 'louder'. Eg. ReplayGain for a song is -7.2 dB; Preamp is set to +6 dB; Final volume setting will be -1.2 dB.
- Show the currently applied song ReplayGain in currently-playing view
- Changed the general behavior of the 'Play', '>>' and '<<' buttons in currently-playing view
  - The play/pause status will not be changed by clicking '<<' or '>>'. If a song is paused and you click '>>' the next song will also be paused. When a song is currently playing and you click '>>' the next song will also be played automatically.
  - Removed the 'Manual Playback' setting
- When a song is starting, song data (eg. playcount) will be automatically fetched from server
  - Local playcounts are disabled as they increased as soon a song started
  - Playcounts are only maintained by the server, no matter if a song is streamed or already downloaded
  - Removed the "Scrobble streamed Songs" setting (always enabled)
- Always remember the playback position of only the currently played song
  - When restarting the app the position of the previously played song will be remembered
  - Removed setting 'Song Playback Resume' as this will remember the playback position of all songs and you might end up with a playlist/album where songs just start anywhere in the middle.
- Add 'Remove from Playlist' to song context menu in playlists
- Clicking on a song in any song-list view will insert the song into the current queue and play it right away. It used to clear the existing queue and insert the currently viewed song-list to the queue. Use 'Play' or 'Shuffle' to replace the current queue with the currently shown song-list
- Show trashcan button in queue view to clear the current queue

### Changes to the Settings menu:
- Added 'Show Star Rating' setting in 'Display and Interaction'
- Removed 'Lyrics Smooth Scrolling' (always enabled) in 'Display and Interaction'
- Moved "Resync Library" to the 'Library' section
- Moved 'Theme Color' from 'Account' to 'Display & Interaction'
- Moved Autocache 'Newest Songs and 'Newest Podcast Episodes' from 'Library' to 'Player, Stream & Scrobble'
- Added 'Preamp' Setting to 'ReplayGain' in 'Player, Stream & Scrobble'
- Removed 'Manual Playback' in 'Player, Stream & Scrobble'
- Removed the "Scrobble streamed Songs" setting (always enabled) in 'Player, Stream & Scrobble'
- Removed setting 'Song Playback Resume' in 'Player, Stream & Scrobble'

## Comparision:

#### Grid view (Amperfy / Musify):
<img src="Assets/amperfy01.jpg" width="400" alt="GridView Amperfy"> <img src="Assets/musify01.jpg" width="400" alt="GridView Musify">

#### Star ratings in song lists (Amperfy / Musify):
<img src="Assets/amperfy02.jpg" width="400" alt="Song-List Amperfy"> <img src="Assets/musify02.jpg" width="400" alt="Song-List Musify">

#### Currently playing view (Amperfy / Musify):
<img src="Assets/amperfy03.jpg" width="400" alt="Currently Playing Amperfy"> <img src="Assets/musify03.jpg" width="400" alt="Currently Playing Musify">

#### Lyrics view (Amperfy / Musify):
<img src="Assets/amperfy04.jpg" width="400" alt="Lyrics View Amperfy"> <img src="Assets/musify04.jpg" width="400" alt="Lyrics View Musify">

#### Context Menu (Amperfy / Amperfy):
<img src="Assets/amperfy05a.jpg" width="400" alt="Context Menu Amperfy"> <img src="Assets/amperfy05b.jpg" width="400" alt="Context Menu Amperfy">

#### Context Menu & Song Info view (Musify / Musify):
<img src="Assets/musify05.jpg" width="400" alt="Context Menu Musify"> <img src="Assets/musify06.jpg" width="400" alt="Song Info Musify">

* * *

# THIS IS THE ORIGINAL AMPERFY README:
