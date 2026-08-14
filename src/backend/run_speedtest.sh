#!/bin/sh
# Yandex Internetometer speed test engine (ash + curl)

# ys_write_status state phase message progress [extra_json]
ys_write_status() {
	local state="$1"
	local phase="$2"
	local message="$3"
	local progress="${4:-0}"
	local extra="${5:-}"
	local ts

	ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
	ys_ensure_tmp
	message=$(ys_json_escape "$message")

	if [ -n "$extra" ]; then
		printf '{"state":"%s","phase":"%s","message":"%s","progress":%s,"time":"%s",%s}\n' \
			"$state" "$phase" "$message" "$progress" "$ts" "$extra" >"$ADDON_STATUS"
	else
		printf '{"state":"%s","phase":"%s","message":"%s","progress":%s,"time":"%s"}\n' \
			"$state" "$phase" "$message" "$progress" "$ts" >"$ADDON_STATUS"
	fi
}

ys_json_escape() {
	echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

ys_fetch_probes() {
	local work="$1"
	local raw=""

	raw=$("$YS_CURL" -sS --max-time 12 \
		-H "User-Agent: $UA" \
		-H "Referer: $REFERER_BY" \
		-H "Accept: application/json" \
		"$PROBES_API_BY" 2>/dev/null) || raw=""

	if [ -z "$raw" ] || ! echo "$raw" | grep -q '"download"'; then
		raw=$("$YS_CURL" -sS --max-time 12 \
			-H "User-Agent: $UA" \
			-H "Referer: $REFERER_RU" \
			-H "Accept: application/json" \
			"$PROBES_API_RU" 2>/dev/null) || raw=""
	fi

	if [ -z "$raw" ] || ! echo "$raw" | grep -q '"download"'; then
		return 1
	fi

	echo "$raw" >"${work}/probes.json"

	# latency / ping URLs
	echo "$raw" | grep -oE 'https://[^"]+/ping[^"]*' | head -n 6 >"${work}/ping_urls"

	# Unique 50mb probe URLs (usually 3 CDN nodes)
	echo "$raw" | grep -oE 'https://[^"]+/probes/50mb[^"]*' | sort -u >"${work}/download_urls"

	# Unique upload URLs without timeout=
	echo "$raw" | grep -oE 'https://[^"]+/upload\?[^"]*' | grep -v 'timeout=' | sort -u >"${work}/upload_urls"

	# Prefer postUrl if present
	echo "$raw" | grep -oE '"postUrl"[[:space:]]*:[[:space:]]*"[^"]+"' \
		| sed 's/.*"\(https:[^"]*\)".*/\1/' \
		| grep -v 'timeout=' \
		| sort -u >"${work}/upload_post_urls"

	if [ -s "${work}/upload_post_urls" ]; then
		cp "${work}/upload_post_urls" "${work}/upload_urls"
	fi

	[ -s "${work}/download_urls" ] || return 1
	return 0
}

ys_get_ipv4() {
	"$YS_CURL" -sS --max-time 5 -H "User-Agent: $UA" "$IPV4_API" 2>/dev/null | tr -d '"' | head -c 64
}

ys_measure_ping() {
	local work="$1"
	local url sample ms sum count avg
	local referer="$REFERER_BY"

	sum=0
	count=0

	while IFS= read -r url; do
		[ -z "$url" ] && continue
		# warm-up
		"$YS_CURL" -s -o /dev/null -I --max-time 4 \
			-H "User-Agent: $UA" -H "Referer: $referer" "$url" >/dev/null 2>&1 || true

		sample=1
		while [ "$sample" -le "$PING_SAMPLES" ]; do
			# HTTP RTT ~ time_starttransfer - time_appconnect (как у CLI Яндекса)
			ms=$("$YS_CURL" -s -o /dev/null \
				-w '%{time_starttransfer} %{time_appconnect}' \
				-I --max-time 4 \
				-H "User-Agent: $UA" -H "Referer: $referer" \
				"$url" 2>/dev/null)
			ms=$(echo "$ms" | awk '{
				ts=$1+0; ta=$2+0; v=(ts-ta)*1000;
				if (v>0) printf "%.1f", v;
				else print "0";
			}')
			if [ -n "$ms" ] && [ "$ms" != "0" ] && [ "$ms" != "0.0" ]; then
				sum=$(echo "$sum $ms" | awk '{printf "%.3f", $1+$2}')
				count=$((count + 1))
			fi
			sample=$((sample + 1))
		done
	done <"${work}/ping_urls"

	if [ "$count" -eq 0 ]; then
		echo "0"
		return
	fi
	echo "$sum $count" | awk '{printf "%.1f", $1/$2}'
}

ys_dl_stream() {
	local url="$1"
	local out="$2"
	local secs="$3"
	local referer="$REFERER_BY"

	nice -n 15 "$YS_CURL" -s -o /dev/null \
		-w '%{speed_download}' \
		--max-time "$secs" \
		--connect-timeout 5 \
		-H "User-Agent: $UA" -H "Referer: $referer" \
		"$url" >"$out" 2>/dev/null || echo "0" >"$out"
}

ys_measure_download() {
	local work="$1"
	local idx=0
	local url pids="" n
	local per="${STREAMS_PER_URL:-2}"
	local maxp="${MAX_PARALLEL:-4}"

	rm -f "${work}"/dl_*

	while IFS= read -r url; do
		[ -z "$url" ] && continue
		n=1
		while [ "$n" -le "$per" ]; do
			[ "$idx" -ge "$maxp" ] && break 2
			idx=$((idx + 1))
			ys_dl_stream "$url" "${work}/dl_${idx}" "$DOWNLOAD_SECONDS" &
			pids="$pids $!"
			n=$((n + 1))
		done
	done <"${work}/download_urls"

	for pid in $pids; do
		wait "$pid" 2>/dev/null || true
	done

	awk '
		{ bps += $1+0 }
		END {
			mbps = bps * 8 / 1000000;
			if (mbps < 0) mbps = 0;
			printf "%.2f", mbps;
		}
	' "${work}"/dl_* 2>/dev/null || echo "0.00"
}

ys_ul_stream() {
	local url="$1"
	local payload="$2"
	local out="$3"
	local secs="$4"
	local referer="$REFERER_BY"

	nice -n 15 "$YS_CURL" -s -X POST --data-binary @"$payload" \
		-o /dev/null \
		-w '%{speed_upload}' \
		--max-time "$secs" \
		--connect-timeout 5 \
		-H "User-Agent: $UA" \
		-H "Referer: $referer" \
		-H "Content-Type: application/octet-stream" \
		"$url" >"$out" 2>/dev/null || echo "0" >"$out"
}

ys_measure_upload() {
	local work="$1"
	local payload="${work}/payload.bin"
	local idx=0
	local url pids="" n
	local per="${STREAMS_PER_URL:-2}"
	local maxp="${MAX_PARALLEL:-4}"

	rm -f "${work}"/ul_*

	if command -v dd >/dev/null 2>&1; then
		dd if=/dev/zero of="$payload" bs=1024 count=$((UPLOAD_PAYLOAD_BYTES / 1024)) 2>/dev/null
	else
		head -c "$UPLOAD_PAYLOAD_BYTES" /dev/zero >"$payload" 2>/dev/null
	fi

	if [ ! -s "$payload" ] || [ ! -s "${work}/upload_urls" ]; then
		echo "0.00"
		rm -f "$payload"
		return
	fi

	while IFS= read -r url; do
		[ -z "$url" ] && continue
		n=1
		while [ "$n" -le "$per" ]; do
			[ "$idx" -ge "$maxp" ] && break 2
			idx=$((idx + 1))
			ys_ul_stream "$url" "$payload" "${work}/ul_${idx}" "$UPLOAD_SECONDS" &
			pids="$pids $!"
			n=$((n + 1))
		done
	done <"${work}/upload_urls"

	for pid in $pids; do
		wait "$pid" 2>/dev/null || true
	done

	rm -f "$payload"

	awk '
		{ bps += $1+0 }
		END {
			mbps = bps * 8 / 1000000;
			if (mbps < 0) mbps = 0;
			printf "%.2f", mbps;
		}
	' "${work}"/ul_* 2>/dev/null || echo "0.00"
}

ys_run_speedtest() {
	local work ipv4 ping_ms dl_mbps ul_mbps ts msg extra

	ys_ensure_tmp
	ys_resolve_curl || {
		ys_write_status "error" "start" "curl not found" 0
		return 1
	}

	if [ -f "$ADDON_LOCK" ]; then
		oldpid=$(cat "$ADDON_LOCK" 2>/dev/null)
		if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
			ys_log "Speedtest already running (pid $oldpid)"
			return 1
		fi
		rm -f "$ADDON_LOCK"
	fi

	echo "$$" >"$ADDON_LOCK"
	work="${ADDON_TMP_DIR}/work.$$"
	mkdir -p "$work"
	rm -f "$ADDON_RESULT"

	ipv4=""
	ping_ms=""
	dl_mbps=""
	ul_mbps=""

	ys_write_status "running" "probes" "Получение серверов Яндекса..." 5
	ys_log "Speedtest started"

	if ! ys_fetch_probes "$work"; then
		msg="Не удалось получить список серверов Яндекса"
		ys_write_status "error" "probes" "$msg" 0
		rm -rf "$work"
		rm -f "$ADDON_LOCK"
		return 1
	fi

	ys_write_status "running" "ip" "Определение внешнего IP..." 12
	ipv4=$(ys_get_ipv4)
	[ -z "$ipv4" ] && ipv4="unknown"
	extra="\"ipv4\":\"$(ys_json_escape "$ipv4")\""
	ys_write_status "running" "ip" "IP: ${ipv4}" 18 "$extra"

	ys_write_status "running" "download" "Измерение входящей скорости (~10 с)..." 25 "$extra"
	dl_mbps=$(ys_measure_download "$work")
	extra="\"ipv4\":\"$(ys_json_escape "$ipv4")\",\"download_mbps\":${dl_mbps:-0}"
	ys_write_status "running" "download" "v ${dl_mbps} Mbps - далее исходящая..." 55 "$extra"

	ys_write_status "running" "upload" "Измерение исходящей скорости (~10 с)..." 65 "$extra"
	ul_mbps=$(ys_measure_upload "$work")
	extra="\"ipv4\":\"$(ys_json_escape "$ipv4")\",\"download_mbps\":${dl_mbps:-0},\"upload_mbps\":${ul_mbps:-0}"
	ys_write_status "running" "upload" "^ ${ul_mbps} Mbps - далее ping..." 85 "$extra"

	ys_write_status "running" "ping" "Измерение задержки (ping)..." 90 "$extra"
	ping_ms=$(ys_measure_ping "$work")

	ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
	ipv4_esc=$(ys_json_escape "$ipv4")

	printf '{"state":"done","phase":"done","message":"Готов к замеру","progress":100,"time":"%s","ipv4":"%s","ping_ms":%s,"download_mbps":%s,"upload_mbps":%s,"engine":"yandex","source":"yandex.ru/internet"}\n' \
		"$ts" "$ipv4_esc" "${ping_ms:-0}" "${dl_mbps:-0}" "${ul_mbps:-0}" >"$ADDON_RESULT"

	cp "$ADDON_RESULT" "$ADDON_STATUS"

	ys_log "Speedtest done: dl=${dl_mbps} ul=${ul_mbps} ping=${ping_ms} ip=${ipv4}"
	rm -rf "$work"
	rm -f "$ADDON_LOCK"
	return 0
}
