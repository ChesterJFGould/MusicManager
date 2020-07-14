#! /bin/bash

audioFormat=wav
scriptPath=$(dirname $(realpath $0))

cd ~/Music

# Unused but still pretty cool
selectSong () {
    rm /tmp/selectSongFeedback
    rm /tmp/selectSongSelected
    touch /tmp/selectSongFeedback
    touch /tmp/selectSongSelected
    ls > /tmp/selectSongFeedback
	tail -n +1 -f /tmp/selectSongFeedback \
	| dmenu -i -l 10 -p "$1" -r \
	| tee /tmp/selectSongSelected \
	| xargs -I {} sh -c "if [ -d "{}" ]; then ls {} | awk '{printf \"{}/\"; print}'; fi" \
	| xargs -n 1 -I {} sh -c 'grep -qxF "{}" /tmp/selectSongFeedback || echo "{}" >> /tmp/selectSongFeedback'

	tail -n 1 /tmp/selectSongSelected
	rm /tmp/selectSongFeedback
}

selectSongShowAll () {
    find | sort -V | sed 's/^./Music/' | dmenu -i -l 10 -p "$1" | sed 's/^Music/./'
}

selectSongShowAllDir () {
	find -type d | sort -V | sed 's/^./Music/' | dmenu -i -l 10 -p "$1" | sed 's/^Music/./'
}

downloadSongYouTube () {
	set -eo pipefail

	html=$(dmenu -i -p "YouTube Search: " \
		| sed 's/ /+/g' \
		| xargs -I {} phantomjs "$scriptPath/phantomjs_curl.js" 'https://www.youtube.com/results?q={}')

	titleHref=$(paste <(echo -e "$html" \
		| pup --charset UTF-8 '#video-title attr{title}' \
		| nl \
		| sed 's/\s/+/g' \
		| sed 's/\[/\(/g' \
		| sed 's/\]/\)/g' ) \
		<(echo -e "$html" \
		| pup '#video-title attr{href}'))

	selectionNumber=$(echo -e "$titleHref" \
		| awk '{print $1}' \
		| sed 's/+/ /g' \
		| dmenu -i -l 10 \
		| awk '{print $1}' )
	
	url=$(echo -e "$titleHref" \
		| awk 'NR == n {print $2}' n=$selectionNumber )

	outputName="$(selectSongShowAllDir 'Output Song Place: ')"

	youtube-dl -o "$outputName.%(ext)s" -x --audio-format $audioFormat youtube.com$url
}

downloadPlaylistYoutube () {
	set -eo pipefail

	html=$(dmenu -i -p "YouTube Search: " \
		| sed 's/ /+/g' \
		| xargs -I {} phantomjs "$scriptPath/phantomjs_curl.js" 'https://www.youtube.com/results?q={}&sp=EgIQAw%253D%253D')

	titleNumVidsHref=$(paste <(echo -e "$html" \
			| pup --charset UTF-8 'span#video-title attr{title}' \
			| nl \
			| sed 's/\s/+/g' \
			| sed 's/\[/\(/g' \
			| sed 's/\]/\)/g' ) \
		<(echo -e "$html" \
			| pup --charset UTF-8 '.ytd-thumbnail-overlay-side-panel-renderer text{}' \
			| uniq \
			| awk 'NF') \
		<(echo -e "$html" \
			| pup 'a[href*="watch"].ytd-playlist-renderer attr{href}' \
			| uniq))

	selectionNumber=$(echo -e "$titleNumVidsHref" \
		| awk '{printf "%s | %s videos\n", $1, $2}' \
		| sed 's/+/ /g' \
		| dmenu -i -l 10 \
		| awk '{print $1}' )

	url=$(echo -e "$titleNumVidsHref" \
		| awk 'NR == n {print $3}' n=$selectionNumber)

	outputFolder=$(selectSongShowAllDir "Output Folder: ")

	youtube-dl -o "$outputFolder/%(playlist_index)s.%(title)s.%(ext)s" -x --audio-format $audioFormat youtube.com$url
}

currentSong () {
	song=$(cmus-remote -Q | grep file)
	song=${song##*/}
	song=${song%.*}

	echo "$song"
}

options="Play\nPause\nNext\nPrevious\nPlay Song\nAdd Song to Queue\nClear Queue\nToggle Loop\nDownload Song From YouTube\nDownload Playlist From YouTube"

case $(echo -e "$options" | dmenu -i -p "$(currentSong)" -l $(echo -e "$options" | wc -l)) in
    "Play")
        cmus-remote -p
        ;;
    "Pause")
     	cmus-remote -u
        ;;
    "Next")
        cmus-remote -n
        ;;
    "Previous")
        cmus-remote -r
        ;;
    "Play Song")
		song=$(selectSongShowAll "Select Song: ")

		if [ -f "$song" ]
		then
    		cmus-remote -f "$song"
    	elif [ -d "$song" ]
    	then
    		cmus-remote -q -c
    		files=$(find "$song" | grep ".$audioFormat" | sort -V)
			cmus-remote -f "$(echo -e "$files" | head -n 1)"
			echo -e "$files" | tail -n +2 | xargs -d "\n" -n 1 -I {} cmus-remote -q "{}"
    	fi
        ;;
    "Add Song to Queue")
        song=$(selectSongShowAll "Select Song: ")
        if [ -f "$song" ]
        then
            cmus-remote -q "$song"
        elif [ -d "$song" ]
        then
        	find "$song" \
        	| grep ".$audioFormat" \
			| sort -V \
        	| xargs -d "\n" -n 1 -I {} cmus-remote -q "{}"
        fi
        ;;
    "Clear Queue")
        cmus-remote -q -c
        ;;
    "Toggle Loop")
	cmus-remote -C "toggle repeat_current"
	;;
    "Download Song From YouTube")
        downloadSongYouTube
        ;;
    "Download Playlist From YouTube")
	downloadPlaylistYoutube	
	;;
esac
