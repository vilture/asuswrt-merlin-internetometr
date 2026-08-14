#!/bin/sh
# Shared paths and constants for Internet-o-metr Merlin addon

ADDON_TAG="internetometr"
ADDON_VERSION="1.1.0"
ADDON_TAB_NAME="Интернетометр"

ADDON_SCRIPT="/jffs/scripts/${ADDON_TAG}"
[ -n "$ADDON_DIR" ] || ADDON_DIR="/jffs/addons/${ADDON_TAG}"
ADDON_WEB_DIR="/www/user/${ADDON_TAG}"
ADDON_TMP_DIR="/tmp/${ADDON_TAG}"

ADDON_LOCK="${ADDON_TMP_DIR}/lock"
ADDON_STATUS="${ADDON_WEB_DIR}/status.json"
ADDON_RESULT="${ADDON_WEB_DIR}/result.json"
ADDON_REQUEST="${ADDON_WEB_DIR}/request.json"
ADDON_LOG="/tmp/${ADDON_TAG}.log"

HOOK_MARKER="#${ADDON_TAG}"

UA="Mozilla/5.0 (Linux; Asuswrt-Merlin) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
REFERER_BY="https://yandex.by/internet/"
REFERER_RU="https://yandex.ru/internet/"
PROBES_API_BY="https://yandex.by/internet/api/v0/get-probes"
PROBES_API_RU="https://yandex.ru/internet/api/v0/get-probes"
IPV4_API="https://ipv4-internet.yandex.net/api/v0/ip"

DOWNLOAD_SECONDS=10
UPLOAD_SECONDS=10
PING_SAMPLES=3
UPLOAD_PAYLOAD_BYTES=20971520
# Keep modest: too many curl+TLS workers freeze httpd on the router
STREAMS_PER_URL=2
MAX_PARALLEL=4

IPERF_SECONDS=10
IPERF_PARALLEL=1

# service-event / httpd PATH is often empty; SSH profile is not sourced
ys_ensure_path() {
	PATH="/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin:/jffs/bin:${PATH}"
	export PATH
}

# Prefer absolute path: interactive PATH on Merlin often omits /usr/sbin
ys_resolve_curl() {
	if [ -n "$YS_CURL" ] && [ -x "$YS_CURL" ]; then
		return 0
	fi
	if [ -x /usr/sbin/curl ]; then
		YS_CURL=/usr/sbin/curl
	elif [ -x /sbin/curl ]; then
		YS_CURL=/sbin/curl
	elif [ -x /opt/bin/curl ]; then
		YS_CURL=/opt/bin/curl
	elif command -v curl >/dev/null 2>&1; then
		YS_CURL=$(command -v curl)
	else
		YS_CURL=""
		return 1
	fi
	return 0
}

ys_log() {
	logger -t "$ADDON_TAG" "$@"
	echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$ADDON_LOG" 2>/dev/null
}

ys_ensure_tmp() {
	mkdir -p "$ADDON_TMP_DIR" 2>/dev/null
	mkdir -p "$ADDON_WEB_DIR" 2>/dev/null
}
