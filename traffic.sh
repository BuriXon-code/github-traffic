#!/bin/bash
# shellcheck disable=SC2207,SC2181

##############################################
# Author: Kamil BuriXon Burek (BuriXon-code) #
# Name: Github-Traffic (c) 2025              #
# Description: Show repos traffic.           #
# Version: v 1.0                             #
# Changelog: release                         #
# Todo:                                      #
##############################################

# declare defaults if are not externaly exported
if [ -z $GITHUB_TOKEN ]; then
	GITHUB_TOKEN=""
fi
if [ -z $GITHUB_USER ]; then
	GITHUB_USER=""
fi

COLOR_MAP=(82 83 118 154 190 226 220 208 203)
COLOR_ZERO=196
COLOR_LINE=248
COLOR_HEADER=123
COLOR_TOTAL_LABEL=250
COLOR_TOTAL_VALUE=123
PRETTY_JSON=false
REPO_STATS=()
SORT_MODE=""
LIMIT_HEIGHT=0
OUTPUT_FORMAT="none"
OUTPUT_FILE=""
CACHE_DIR="$HOME/.cache/BuriXon-code/github/$GITHUB_USER"
CACHE_FILE="$CACHE_DIR/traffic_stats"
PER_PAGE=100
LIMITED=false

mkdir -p "$CACHE_DIR"
touch "$CACHE_FILE"

if ! [[ -t 0 ]]; then
	echo -e "Warning: command does not accept parameters from pipe or other commands." >&2
fi

help() {
	echo "Usage: $(basename "$0") [options]"
	echo "  -c | --sort=clones       Sort by clone count"
	echo "  -v | --sort=visits       Sort by visit count"
	echo "  -l | --lines <n>         Limit results to first n"
	echo "                           (default: limited by -p option)"
	echo "  -p | --per-page <n>      Limit repo count per page"
	echo "                           (default: 100)"
	echo "  -u | --username <name>   GitHub username"
	echo "  -t | --token <token>     GitHub token"
	echo "  -f | --format <fmt>      Output format: none, json, csv"
	echo "  -j | --pretty-json       Convert output json to pretty format"
	echo "  -o | --output <file>     Output file (used only with json/csv)"
	exit "$1"
}

while [ $# -gt 0 ]; do
	case "$1" in
		-c|--sort=clones)
			[ "$SORT_MODE" = "visits" ] && echo "Error: options -c and -v are mutually exclusive" >&2 && exit 1
			SORT_MODE="clones"
			;;
		-v|--sort=visits)
			[ "$SORT_MODE" = "clones" ] && echo "Error: options -c and -v are mutually exclusive" >&2 && exit 1
			SORT_MODE="visits"
			;;
		-l|--lines)
			shift
			[[ -z "$1" || "$1" == -* ]] && echo "Error: option -l requires a value." >&2 && exit 1
			LIMIT_HEIGHT="$1"
			LIMITED=true
			;;
		-p|--per-page)
			shift
			[[ -z "$1" || "$1" == -* ]] && echo "Error: option -p requires a value." >&2 && exit 1
			if [[ "$1" =~ ^[0-9]+$ ]]; then
				PER_PAGE="$1"
			else
				echo "Error: invalid value for '-p|--per-page' option." >&2
				exit 1
			fi
			;;
		-u|--username)
			shift
			GITHUB_USER="$1"
			CACHE_DIR="$HOME/.cache/BuriXon-code/github/$GITHUB_USER"
			;;
		-t|--token)
			shift
			GITHUB_TOKEN="$1"
			;;
		-f|--format)
			shift
			OUTPUT_FORMAT="$1"
			;;
		-j|--pretty-json)
			PRETTY_JSON=true
			;;
		-o|--output)
			shift
			OUTPUT_FILE="$1"
			;;
		-h)
			help 0
			;;
		*)
			echo -e "Error: invalid option '$1'." >&2
			echo
			help 1
			;;
	esac
	shift
done

# PARSOWANIE
# token
if ! [[ "$GITHUB_TOKEN" =~ ^ghp_[[:alnum:]]+$ || -n "$GITHUB_TOKEN" ]]; then
	echo "Error: invalid or missing API token." >&2
	exit 1
fi
# user
if [ -z "$GITHUB_USER" ]; then
	echo "Error: missing username." >&2
	exit 1
fi
# format
if ! [[ "$OUTPUT_FORMAT" =~ ^(none|json|csv)$ ]]; then
	echo "Error: invalid output format '$OUTPUT_FORMAT'." >&2
	exit 1
fi
# pretty vs csv
if $PRETTY_JSON && [ "$OUTPUT_FORMAT" != "json" ]; then
	echo "Error: the '-j|--pretty-json' option can only be used with the json format." >&2
	exit 1
fi
# if -o exists
if [[ -f "$OUTPUT_FILE" ]]; then
	echo -n "File '$OUTPUT_FILE' already exists. Overwrite? [y/N]: "
	read -n 1 -r ANSWER
	echo
	if [[ ! "$ANSWER" =~ ^[yY]$ ]]; then
		echo "Aborted."
		exit 1
	fi
fi
# zapisywalny plik
if [ -n "$OUTPUT_FILE" ]; then
	if ! touch "$OUTPUT_FILE" 2>/dev/null; then
		echo "Permission denied: cannot write to '$OUTPUT_FILE'." >&2
		exit 1
	fi
fi
# linijki
if ! [[ "$LIMIT_HEIGHT" =~ ^[0-9]+$ ]]; then
	echo "Error: invalid value for '-l|--lines' option." >&2
	exit 1
fi
# Sprawdzenie, czy SORT_MODE jest poprawny
if [[ "$SORT_MODE" != "" && "$SORT_MODE" != "clones" && "$SORT_MODE" != "visits" ]]; then
    echo "Error: invalid sort option." >&2
    exit 1
fi

# Obsługa przypadku, gdy OUTPUT_FORMAT nie jest "none"
if [[ "$OUTPUT_FORMAT" != "none" ]]; then
    # Jeśli OUTPUT_FORMAT to json lub csv, to SORT_MODE musi być pusty, a LIMIT_HEIGHT = 0
    if [[ "$SORT_MODE" != "" || "$LIMIT_HEIGHT" -ne 0 ]]; then
	    echo "Error: only default format can be sorted." >&2
        exit 1
    fi
fi

tput civis

show_spinner() {
	while :; do
		for f in ' ⡿' ' ⣟' ' ⣯' ' ⣷' ' ⣾' ' ⣽' ' ⣻' ' ⢿'; do
			printf "\rFetching data\033[1;36m%s\033[0m\e[K" "$f"
			sleep 0.1
		done
	done
}

stop_spinner() {
	kill -9 $SPINNER_PID 2>/dev/null
	wait $SPINNER_PID 2>/dev/null
	printf "\r\e[K"
	tput cnorm
}

trap 'tput cnorm; echo -e "\rAborted.\e[K"; kill -9 $SPINNER_PID &>/dev/null; exit 1' INT
show_spinner & SPINNER_PID=$!

repos=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
	"https://api.github.com/users/$GITHUB_USER/repos?per_page=$PER_PAGE")

if [ $? -ne 0 ] || [ -z "$repos" ]; then
	stop_spinner
	echo "Error: error fetching repository list" >&2
	exit 1
fi

if [ "$LIMITED" = "true" ]; then
	REPO_COUNT=$(echo "$repos" | jq 'length')
fi

repos=$(echo "$repos" | jq -r '.[].name' 2>/dev/null)
if [ $? -ne 0 ]; then
	stop_spinner
	echo "Error: error parsing repository list" >&2
	exit 1
fi

for name in $repos; do
	clones=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
		"https://api.github.com/repos/$GITHUB_USER/$name/traffic/clones")
	if [ $? -ne 0 ] || [ -z "$clones" ]; then
		stop_spinner
		echo "Error: error fetching clones for $name" >&2
		exit 1
	fi
	clones_count=$(echo "$clones" | jq '.count // 0' 2>/dev/null)
	if [ $? -ne 0 ]; then
		stop_spinner
		echo "Error: error parsing clones JSON for $name" >&2
		exit 1
	fi

	visits=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
		"https://api.github.com/repos/$GITHUB_USER/$name/traffic/views")
	if [ $? -ne 0 ] || [ -z "$visits" ]; then
		stop_spinner
		echo "Error: error fetching views for $name" >&2
		exit 1
	fi
	visits_count=$(echo "$visits" | jq '.count // 0' 2>/dev/null)
	if [ $? -ne 0 ]; then
		stop_spinner
		echo "Error: error parsing views JSON for $name" >&2
		exit 1
	fi

	REPO_STATS+=("$name:$clones_count:$visits_count")
done

stop_spinner

case $SORT_MODE in
	clones) REPO_STATS=( $(printf "%s\n" "${REPO_STATS[@]}" | sort -t: -k2 -nr) ) ;;
	visits) REPO_STATS=( $(printf "%s\n" "${REPO_STATS[@]}" | sort -t: -k3 -nr) ) ;;
esac

if (( LIMIT_HEIGHT > 0 )); then
	REPO_STATS=( "${REPO_STATS[@]:0:LIMIT_HEIGHT}" )
fi

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
	json="["
	for stat in "${REPO_STATS[@]}"; do
		IFS=":" read -r n c v <<< "$stat"
		json+="{\"repo\":\"$n\",\"clones\":$c,\"visits\":$v},"
	done
	json="${json%,}]"
	#TODO
	if [ -n "$OUTPUT_FILE" ]; then
		if $PRETTY_JSON; then
			echo "$json" | jq -M > "$OUTPUT_FILE"
		else
			echo "$json" > "$OUTPUT_FILE"
		fi
	else
		if $PRETTY_JSON; then
			echo "$json" | jq -M
		else
			echo "$json"
		fi
	fi
	exit 0
fi

if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
	[[ -n "$OUTPUT_FILE" ]] && exec > "$OUTPUT_FILE"
	echo "Repository,Clones,Visits"
	for stat in "${REPO_STATS[@]}"; do
		IFS=":" read -r n c v <<< "$stat"
		echo "$n,$c,$v"
	done
	exit 0
fi

max_clones=0; max_visits=0
for stat in "${REPO_STATS[@]}"; do
	IFS=":" read -r _ c v <<< "$stat"
	(( c > max_clones )) && max_clones=$c
	(( v > max_visits )) && max_visits=$v
done

get_color() {
	local val=$1 max=$2
	(( val == 0 || max == 0 )) && echo "$COLOR_ZERO" && return
	local levels=$(( ${#COLOR_MAP[@]} - 1 ))
	local idx=$(( (max - val) * levels / max ))
	(( idx < 0 )) && idx=0
	(( idx > levels )) && idx=$levels
	echo "${COLOR_MAP[$idx]}"
}

name_w=20
for stat in "${REPO_STATS[@]}"; do
	IFS=":" read -r nm _ _ <<< "$stat"
	(( ${#nm} > name_w )) && name_w=${#nm}
done
clone_w=10; visit_w=10; spacer="    "

printf "\n\e[38;5;${COLOR_HEADER}m%-${name_w}s${spacer}%${clone_w}s${spacer}%$((visit_w+2))s\e[0m\n" \
	"Repository" "Clones" "Visits"
printf "\e[38;5;${COLOR_LINE}m%0.s-" $(seq 1 $((name_w+clone_w+visit_w+${#spacer}*2 + 2))) ; echo -e "\e[0m"

sum_c=0; sum_v=0; count=0
for stat in "${REPO_STATS[@]}"; do
	(( LIMIT_HEIGHT>0 && count>=LIMIT_HEIGHT )) && break
	IFS=":" read -r nm c v <<< "$stat"
	sum_c=$((sum_c+c)); sum_v=$((sum_v+v))

	raw_c=$(printf "%${clone_w}d" "$c")
	raw_v=$(printf "%${visit_w}d" "$v")
	colc=$(get_color "$c" "$max_clones")
	colv=$(get_color "$v" "$max_visits")

	prev_data=$(grep -m 1 "^$nm:" "$CACHE_FILE")
	prev_c=0; prev_v=0
	if [[ -n "$prev_data" ]]; then
		IFS=":" read -r _ prev_c prev_v <<< "$prev_data"
	fi

	arrow_c=" "
	(( c > prev_c )) && arrow_c="↑"
	(( c < prev_c )) && arrow_c="↓"

	arrow_v=" "
	(( v > prev_v )) && arrow_v="↑"
	(( v < prev_v )) && arrow_v="↓"

	if [[ -n "$prev_data" ]]; then
		sed -i "s/^$nm:[^:]*:[^:]*$/$nm:$c:$v/" "$CACHE_FILE"
	else
		echo "$nm:$c:$v" >> "$CACHE_FILE"
	fi

	printf "%-${name_w}s${spacer}\e[38;5;${colc}m${raw_c} ${arrow_c}\e[0m${spacer}\e[38;5;${colv}m${raw_v} ${arrow_v}\e[0m\n" \
		"$nm"
	((count++))
done

if $LIMITED; then
	MORE=$(( REPO_COUNT - LIMIT_HEIGHT ))
	echo -e "\e[3;38;5;${COLOR_LINE}m... + $MORE more\e[0m"
fi
printf "\e[38;5;${COLOR_LINE}m%0.s-" $(seq 1 $((name_w+clone_w+visit_w+${#spacer}*2 + 2))) ; echo -e "\e[0m"

raw_tc=$(printf "%${clone_w}d" "$sum_c")
raw_tv=$(printf "%${visit_w}d" "$sum_v")
printf "\e[38;5;${COLOR_TOTAL_LABEL}m%-${name_w}s${spacer}\e[38;5;${COLOR_TOTAL_VALUE}m${raw_tc}\e[0m${spacer}  \e[38;5;${COLOR_TOTAL_VALUE}m${raw_tv}\e[0m\n\a" \
	"Total"
echo
