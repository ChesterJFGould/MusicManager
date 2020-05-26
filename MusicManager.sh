#! /bin/bash

audioFormat=wav

cd ~/Music

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

downloadYouTube () {
	set -eo pipefail

	html=$(dmenu -i -p "YouTube Search: " | sed 's/ /+/g' | xargs -I~ curl -s https://www.youtube.com/results?q=~)

	titleHref=$(paste <(echo -e "$html" | pup --charset UTF-8 '.yt-uix-tile-link[href*="watch"] attr{title}' \
	| nl | sed 's/\s/+/g') <(echo -e "$html" | pup '.yt-uix-tile-link[href*="watch"] attr{href}'))

	echo -e "$titleHref"

	url=$(echo -e "$titleHref" | awk '{print $(1)}' | sed 's/+/ /g' | dmenu -i -l 10 | sed 's/ /+/g' \
	| xargs -I ~ grep ~ <(echo -e "$titleHref") | awk '{print $(2)}')

	outputName=$(selectSong "Output Song Name: ")

	echo -e "Selected Url $url"

	youtube-dl -o "$outputName.%(ext)s" -x --audio-format $audioFormat youtube.com$url 2>> ~/musicManagerLogfile.txt
}

options="Play\nPause\nNext\nPrevious\nPlay Song\nAdd Song to Queue\nDownload Song From YouTube"

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
		song=$(selectSong "Select Song: ")
		if [ -f $song ]
		then
    		cmus-remote -f $song
    	elif [ -d $song ]
    	then
        	case $(echo -e "Yes\nNo" | dmenu -i -p "Clear Queue?") in
				"Yes")
    				cmus-remote -q -c
    				;;
			esac
    		files=$(find "$PWD/$song" | grep ".$audioFormat")
    		echo -e "$files"
			cmus-remote -f "$(echo -e "$files" | head -n 1)"
			echo -e "$files" | tail -n +2 | xargs -n 1 -I {} cmus-remote -q {}
    	fi
        ;;
    "Add Song to Queue")
        song=$(selectSong "Select Song: ")
        if [ -f $song ]
        then
            cmus-remote -q $song
        elif [ -d $song ]
        then
        	find "$PWD/$song" \
        	| grep ".$audioFormat" \
        	| xargs -n 1 -I {} cmus-remote -q "{}"
        fi
        ;;
    "Download Song From YouTube")
        downloadYouTube
        ;;
esac
