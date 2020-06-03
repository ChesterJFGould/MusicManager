#! /bin/bash

audioFormat=wav

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
		| xargs -I {} curl -s https://www.youtube.com/results?q={})

	titleHref=$(paste <(echo -e "$html" \
		| pup --charset UTF-8 '.yt-uix-tile-link[href*="watch"] attr{title}' \
		| nl \
		| sed 's/\s/+/g' \
		| sed 's/\[/\(/g' \
		| sed 's/\]/\)/g' ) <(echo -e "$html" \
		| pup '.yt-uix-tile-link[href*="watch"] attr{href}'))

	selectionNumber=$(echo -e "$titleHref" \
		| awk '{print $1}' \
		| sed 's/+/ /g' \
		| dmenu -i -l 10 \
		| awk '{print $1}' )
	
	url=$(echo -e "$titleHref" \
		| awk 'NR == n {print $2}' n=$selectionNumber )

	outputName=$(selectSongShowAllDir "Output Song Place: ")

	youtube-dl -o "$outputName.%(ext)s" -x --audio-format $audioFormat youtube.com$url
}

downloadPlaylistYoutube () {
	set -eo pipefail

	html=$(dmenu -i -p "YouTube Search: " \
		| sed 's/ /+/g' \
		| xargs -I {} curl -s 'https://www.youtube.com/results?q={}&sp=EgIQAw%253D%253D')

	titleNumVidsHref=$(paste 	<(echo -e "$html" \
									| pup --charset UTF-8 '.yt-uix-tile-link[href*="watch"] attr{title}' \
									| nl \
									| sed 's/\s/+/g' \
									| sed 's/\[/\(/g' \
									| sed 's/\]/\)/g' ) \
								<(echo -e "$html" \
									| pup --charset UTF-8 '.formatted-video-count-label b text{}') \
								<(echo -e "$html" \
									| pup '.yt-uix-tile-link[href*="watch"] attr{href}'))

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

options="Play\nPause\nNext\nPrevious\nPlay Song\nAdd Song to Queue\nClear Queue\nDownload Song From YouTube\nDownload Playlist From YouTube"

case $(echo -e "$options" | dmenu -i -l $(echo -e "$options" | wc -l)) in
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
    		echo -e "$files"
			cmus-remote -f "$(echo -e "$files" | head -n 1)"
			echo -e "$files" | tail -n +2 | xargs -0 -n 1 -I {} cmus-remote -q "{}"
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
        	| xargs -0 -n 1 -I {} cmus-remote -q "{}"
        fi
        ;;
    "Clear Queue")
        cmus-remote -q -c
        ;;
    "Download Song From YouTube")
        downloadSongYouTube
        ;;
	"Download Playlist From YouTube")
		downloadPlaylistYoutube	
		;;
esac
