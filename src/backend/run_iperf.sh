#!/bin/sh
# Direct iperf3 speed test against public regional servers

ys_iperf3_usable() {
	local bin="$1"
	[ -n "$bin" ] || return 1
	[ -e "$bin" ] || [ -L "$bin" ] || return 1
	[ -x "$bin" ] && return 0
	"$bin" -v >/dev/null 2>&1 && return 0
	return 1
}

ys_resolve_iperf3() {
	local cand found

	if ys_iperf3_usable "$YS_IPERF3"; then
		return 0
	fi

	ys_ensure_path

	for cand in \
		/opt/bin/iperf3 \
		/opt/sbin/iperf3 \
		/usr/bin/iperf3 \
		/usr/sbin/iperf3 \
		/bin/iperf3 \
		/sbin/iperf3 \
		/jffs/bin/iperf3
	do
		if ys_iperf3_usable "$cand"; then
			YS_IPERF3="$cand"
			return 0
		fi
	done

	found=$(command -v iperf3 2>/dev/null) || found=""
	if [ -z "$found" ]; then
		found=$(which iperf3 2>/dev/null) || found=""
	fi
	if ys_iperf3_usable "$found"; then
		YS_IPERF3="$found"
		return 0
	fi

	YS_IPERF3=""
	return 1
}

# Extract bits_per_second from iperf3 -J output (prefer sum_received)
ys_iperf_json_bps() {
	local file="$1"
	local bps

	[ -f "$file" ] || {
		echo "0"
		return 1
	}

	bps=$(sed -n '/"sum_received"/,/}/p' "$file" 2>/dev/null \
		| grep -oE '"bits_per_second"[[:space:]]*:[[:space:]]*[0-9.eE+-]+' \
		| head -1 \
		| grep -oE '[0-9.eE+-]+$')
	if [ -z "$bps" ]; then
		bps=$(sed -n '/"sum_sent"/,/}/p' "$file" 2>/dev/null \
			| grep -oE '"bits_per_second"[[:space:]]*:[[:space:]]*[0-9.eE+-]+' \
			| head -1 \
			| grep -oE '[0-9.eE+-]+$')
	fi
	if [ -z "$bps" ]; then
		bps=$(grep -oE '"bits_per_second"[[:space:]]*:[[:space:]]*[0-9.eE+-]+' "$file" 2>/dev/null \
			| tail -1 \
			| grep -oE '[0-9.eE+-]+$')
	fi
	[ -n "$bps" ] || bps="0"
	echo "$bps"
}

ys_bps_to_mbps() {
	echo "$1" | awk '{
		s=$1
		gsub(/ /,"",s)
		n=s+0
		if ((n==0) && (s ~ /[eE]/)) {
			split(s,a,"[eE]")
			n=a[1]*(10^a[2])
		}
		printf "%.2f", n/1000000
	}'
}

ys_iperf_has_error() {
	local file="$1"
	grep -qE '"error"[[:space:]]*:[[:space:]]*"[^"]+"' "$file" 2>/dev/null
}

ys_iperf_error_text() {
	local file="$1"
	grep -oE '"error"[[:space:]]*:[[:space:]]*"[^"]*"' "$file" 2>/dev/null \
		| head -1 \
		| sed 's/.*"error"[[:space:]]*:[[:space:]]*"//;s/"$//'
}

# Probe ports until one accepts a short test; sets YS_IPERF_PORT
ys_iperf_pick_port() {
	local host="$1"
	local ports="$2"
	local work="$3"
	local port out err

	YS_IPERF_PORT=""
	for port in $ports; do
		out="${work}/probe_${port}.json"
		err="${work}/probe_${port}.err"
		rm -f "$out" "$err"
		nice -n 15 "$YS_IPERF3" -c "$host" -p "$port" -n 32768 -J >"$out" 2>"$err"
		if [ -s "$out" ] && ! ys_iperf_has_error "$out"; then
			bps=$(ys_iperf_json_bps "$out")
			# Accept even low bps if JSON is valid (1s probe)
			if [ -n "$bps" ]; then
				YS_IPERF_PORT="$port"
				return 0
			fi
		fi
		# Also accept if stderr empty and exit ok with json
		if [ -s "$out" ] && ! grep -qiE 'busy|refused|unable to connect|no route|timed out|error' "$err" 2>/dev/null; then
			if ! ys_iperf_has_error "$out"; then
				YS_IPERF_PORT="$port"
				return 0
			fi
		fi
		ys_log "iperf probe $host:$port failed: $(cat "$err" 2>/dev/null | head -c 120) $(ys_iperf_error_text "$out")"
	done
	return 1
}

ys_iperf_measure() {
	local host="$1"
	local port="$2"
	local work="$3"
	local reverse="$4"
	local out bps mbps
	local args="-c $host -p $port -t $IPERF_SECONDS -P $IPERF_PARALLEL -J"

	out="${work}/iperf_${reverse}.json"
	if [ "$reverse" = "download" ]; then
		# shellcheck disable=SC2086
		"$YS_IPERF3" $args -R >"$out" 2>/dev/null || true
	else
		# shellcheck disable=SC2086
		"$YS_IPERF3" $args >"$out" 2>/dev/null || true
	fi

	if ys_iperf_has_error "$out"; then
		echo "0.00"
		return 1
	fi
	bps=$(ys_iperf_json_bps "$out")
	mbps=$(ys_bps_to_mbps "$bps")
	echo "$mbps"
}

ys_iperf_ping() {
	local host="$1"
	local avg

	avg=$(ping -c 3 -W 2 "$host" 2>/dev/null \
		| grep -oE 'avg[=/][0-9.]+' \
		| head -1 \
		| grep -oE '[0-9.]+')
	if [ -z "$avg" ]; then
		avg=$(ping -c 3 -W 2 "$host" 2>/dev/null \
			| grep 'min/avg/max' \
			| sed -n 's|.*= *\([0-9.]*\)/\([0-9.]*\)/.*|\2|p')
	fi
	if [ -z "$avg" ]; then
		echo "0"
		return 1
	fi
	echo "$avg" | awk '{printf "%.1f", $1+0}'
}

ys_read_request_engine() {
	local f="$ADDON_REQUEST"
	local engine="yandex"

	if [ -f "$f" ]; then
		if grep -q '"engine"[[:space:]]*:[[:space:]]*"iperf"' "$f" 2>/dev/null; then
			engine="iperf"
		fi
	fi
	echo "$engine"
}

ys_read_request_server_id() {
	local f="$ADDON_REQUEST"
	local id=""

	if [ -f "$f" ]; then
		id=$(grep -oE '"server_id"[[:space:]]*:[[:space:]]*"[^"]+"' "$f" 2>/dev/null \
			| head -1 \
			| sed 's/.*"server_id"[[:space:]]*:[[:space:]]*"//;s/"$//')
	fi
	echo "$id"
}

ys_write_request() {
	local engine="$1"
	local server_id="$2"

	ys_ensure_tmp
	printf '{"engine":"%s","server_id":"%s"}\n' \
		"$(ys_json_escape "$engine")" \
		"$(ys_json_escape "$server_id")" >"$ADDON_REQUEST"
}

ys_run_iperf() {
	local work ipv4 ping_ms dl_mbps ul_mbps ts extra
	local server_id ports host label region port

	ys_ensure_tmp
	ys_ensure_path
	ys_resolve_iperf3 || {
		ys_write_status "error" "start" "iperf3 не найден в /opt/bin, /usr/bin и PATH" 0
		ys_log "iperf3 not found PATH=$PATH"
		return 1
	}
	ys_log "using iperf3=$YS_IPERF3"

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

	server_id=$(ys_read_request_server_id)
	[ -n "$server_id" ] || server_id="nsk_er"

	ys_write_status "running" "probes" "Поиск сервера iperf..." 5
	ys_log "iperf started id=$server_id iperf3=$YS_IPERF3"

	if ! ys_iperf_lookup "$server_id"; then
		ys_write_status "error" "probes" "Неизвестный сервер: $server_id" 0
		rm -rf "$work"
		rm -f "$ADDON_LOCK"
		return 1
	fi

	host="$YS_SRV_HOST"
	label="$YS_SRV_LABEL"
	region="$YS_SRV_REGION"
	ports=$(ys_expand_ports "$YS_SRV_PORTS")

	ys_write_status "running" "probes" "Проверка портов ${host}..." 10 \
		"\"engine\":\"iperf\",\"server\":\"$(ys_json_escape "$label")\",\"host\":\"$(ys_json_escape "$host")\",\"region\":\"$(ys_json_escape "$region")\""

	if ! ys_iperf_pick_port "$host" "$ports" "$work"; then
		ys_write_status "error" "probes" "Нет доступного порта на ${host}" 0 \
			"\"engine\":\"iperf\",\"server\":\"$(ys_json_escape "$label")\",\"host\":\"$(ys_json_escape "$host")\""
		rm -rf "$work"
		rm -f "$ADDON_LOCK"
		return 1
	fi
	port="$YS_IPERF_PORT"
	sleep 1

	ys_resolve_curl && ipv4=$(ys_get_ipv4) || ipv4=""
	[ -z "$ipv4" ] && ipv4="unknown"

	extra="\"engine\":\"iperf\",\"server\":\"$(ys_json_escape "$label")\",\"host\":\"$(ys_json_escape "$host")\",\"port\":${port},\"region\":\"$(ys_json_escape "$region")\",\"ipv4\":\"$(ys_json_escape "$ipv4")\""
	ys_write_status "running" "probes" "Порт ${port} OK" 20 "$extra"

	ys_write_status "running" "download" "iPerf download ${host}:${port} (~${IPERF_SECONDS} с)..." 25 "$extra"
	dl_mbps=$(ys_iperf_measure "$host" "$port" "$work" "download")
	extra="${extra},\"download_mbps\":${dl_mbps:-0}"
	ys_write_status "running" "download" "v ${dl_mbps} Mbps" 55 "$extra"

	ys_write_status "running" "upload" "iPerf upload ${host}:${port} (~${IPERF_SECONDS} с)..." 65 "$extra"
	ul_mbps=$(ys_iperf_measure "$host" "$port" "$work" "upload")
	extra="${extra},\"upload_mbps\":${ul_mbps:-0}"
	ys_write_status "running" "upload" "^ ${ul_mbps} Mbps" 85 "$extra"

	ys_write_status "running" "ping" "ICMP ping ${host}..." 90 "$extra"
	ping_ms=$(ys_iperf_ping "$host")
	[ -z "$ping_ms" ] && ping_ms="0"

	ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)

	printf '{"state":"done","phase":"done","message":"Готов к замеру","progress":100,"time":"%s","ipv4":"%s","ping_ms":%s,"download_mbps":%s,"upload_mbps":%s,"engine":"iperf","server":"%s","host":"%s","port":%s,"region":"%s","source":"iperf3"}\n' \
		"$ts" \
		"$(ys_json_escape "$ipv4")" \
		"${ping_ms:-0}" \
		"${dl_mbps:-0}" \
		"${ul_mbps:-0}" \
		"$(ys_json_escape "$label")" \
		"$(ys_json_escape "$host")" \
		"$port" \
		"$(ys_json_escape "$region")" >"$ADDON_RESULT"

	cp "$ADDON_RESULT" "$ADDON_STATUS"
	ys_log "iperf done: $host:$port dl=${dl_mbps} ul=${ul_mbps} ping=${ping_ms}"
	rm -rf "$work"
	rm -f "$ADDON_LOCK"
	return 0
}
