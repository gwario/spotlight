#!/usr/bin/env bash

dataPath="${XDG_DATA_HOME:-$HOME/.local/share}"

backgroundsPath="$dataPath/spotlight-images"

function showHelp()
{
	echo "Usage: $0 [-d <destination>]"
	echo ""
	echo "Options:"
	echo "	-h shows this help message"
	echo "	-d stores the image into the given destination. Defaults to \"$HOME/.local/share/spotlight-images\"."
}

while getopts "hkd:" opt
do
	case $opt
	in
		'd')
			backgroundsPath=$OPTARG
		;;
		'h'|'?')
			showHelp
			exit 0
		;;
	esac
done

function decodeURL
{
	printf "%b\n" "$(sed 's/+/ /g; s/%\([0-9A-F][0-9A-F]\)/\\x\1/g')"
}

response=$(wget -qO- -U "WindowsShellClient/0" "https://arc.msn.com/v3/Delivery/Placement?pid=209567&fmt=json&cdm=1&lc=en,en-US&ctry=US")
status=$?

if [ $status -ne 0 ]
then
	systemd-cat -t spotlight -p emerg <<< "Query failed"
	exit $status
fi

item=$(jq -r ".batchrsp.items[0].item" <<< $response)

landscapeUrl=$(jq -r ".ad.image_fullscreen_001_landscape.u" <<< $item)
sha256=$(jq -r ".ad.image_fullscreen_001_landscape.sha256" <<< $item | base64 -d | hexdump -ve "1/1 \"%.2x\"")
title=$(jq -r ".ad.title_text.tx" <<< $item)
searchTerms=$(jq -r ".ad.title_destination_url.u" <<< $item | sed "s/.*q=\([^&]*\).*/\1/" | decodeURL)

mkdir -p "$backgroundsPath"
imagePath="$backgroundsPath/$(date +%y-%m-%d-%H-%M-%S)-$title ($searchTerms).jpg"

wget -qO "$imagePath" "$landscapeUrl"
sha256calculated=$(sha256sum "$imagePath" | cut -d " " -f 1)

if [ "$sha256" != "$sha256calculated" ]
then
    	rm "${imagePath:Q}"
	systemd-cat -t spotlight -p emerg <<< "Checksum incorrect"
	exit 1
fi

systemd-cat -t spotlight -p info <<< "Background downloaded: $title ($searchTerms)"
