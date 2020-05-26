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
    find | sort | sed 's/^./Music/' | dmenu -i -l 10 -p "$1" | sed 's/^Music/./'
}

selectSongShowAllDir () {
	find -type -d | sort | sed 's/^./Music/' | dmenu -i -l 10 -p "$1" | sed 's/^Music//'
}

downloadYouTube () {
	set -eo pipefail

	html=$(dmenu -i -p "YouTube Search: " | sed 's/ /+/g' | xargs -I~ curl -s https://www.youtube.com/results?q=~)

	titleHref=$(paste <(echo -e "$html" | pup --charset UTF-8 '.yt-uix-tile-link[href*="watch"] attr{title}' \
	| nl | sed 's/\s/+/g') <(echo -e "$html" | pup '.yt-uix-tile-link[href*="watch"] attr{href}'))

	echo -e "$titleHref"

	url=$(echo -e "$titleHref" | awk '{print $(1)}' | sed 's/+/ /g' | dmenu -i -l 10 | sed 's/ /+/g' \
	| xargs -I ~ grep ~ <(echo -e "$titleHref") | awk '{print $(2)}')

	outputName=$(selectSongShowAllDir "Output Song Place: ")

	youtube-dl -o "$outputName.%(ext)s" -x --audio-format $audioFormat youtube.com$url
}

options="Play\nPause\nNext\nPrevious\nPlay Song\nAdd Song to Queue\nClear Queue\nDownload Song From YouTube"

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
		echo $song
		if [ -f "$song" ]
		then
    		cmus-remote -f "$song"
    	elif [ -d "$song" ]
    	then
        	case $(echo -e "Yes\nNo" | dmenu -i -p "Clear Queue?") in
				"Yes")
    				cmus-remote -q -c
    				;;
			esac
    		files=$(find "$song" | grep ".$audioFormat" | sort)
    		echo -e "$files"
			cmus-remote -f "$(echo -e "$files" | head -n 1)"
			echo -e "$files" | tail -n +2 | xargs -n 1 -I {} cmus-remote -q {}
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
        	| xargs -n 1 -I {} cmus-remote -q "{}"
        fi
        ;;
    "Clear Queue")
        cmus-remote -q -c
        ;;
    "Download Song From YouTube")
        downloadYouTube
        ;;
esac
