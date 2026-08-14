#!/bin/sh
# iperf public server catalog helpers

ys_iperf_list_file() {
	if [ -f "${ADDON_DIR}/iperf_servers.list" ]; then
		echo "${ADDON_DIR}/iperf_servers.list"
	elif [ -f "${ADDON_DIR}/backend/iperf_servers.list" ]; then
		echo "${ADDON_DIR}/backend/iperf_servers.list"
	else
		echo ""
	fi
}

# Expand "5201-5209" / "5201,5203-5209" -> space-separated ports
ys_expand_ports() {
	local spec="$1"
	local part a b p out=""
	local IFS_SAVE="$IFS"

	IFS=","
	# shellcheck disable=SC2086
	set -- $spec
	IFS="$IFS_SAVE"

	for part in "$@"; do
		part=$(echo "$part" | tr -d ' ')
		case "$part" in
			*-*)
				a=${part%-*}
				b=${part#*-}
				p=$a
				while [ "$p" -le "$b" ] 2>/dev/null; do
					out="$out $p"
					p=$((p + 1))
				done
				;;
			*)
				[ -n "$part" ] && out="$out $part"
				;;
		esac
	done
	echo "$out" | sed 's/^ *//'
}

# Lookup server by id -> sets YS_SRV_ID REGION LABEL HOST PORTS_SPEC
ys_iperf_lookup() {
	local want="$1"
	local file line id region label host ports

	YS_SRV_ID=""
	YS_SRV_REGION=""
	YS_SRV_LABEL=""
	YS_SRV_HOST=""
	YS_SRV_PORTS=""

	file=$(ys_iperf_list_file)
	[ -n "$file" ] || return 1

	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in
			""|\#*) continue ;;
		esac
		id=${line%%|*}
		rest=${line#*|}
		region=${rest%%|*}
		rest=${rest#*|}
		label=${rest%%|*}
		rest=${rest#*|}
		host=${rest%%|*}
		ports=${rest#*|}

		if [ "$id" = "$want" ]; then
			YS_SRV_ID="$id"
			YS_SRV_REGION="$region"
			YS_SRV_LABEL="$label"
			YS_SRV_HOST="$host"
			YS_SRV_PORTS="$ports"
			return 0
		fi
	done <"$file"
	return 1
}
