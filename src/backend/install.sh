#!/bin/sh
# Install / uninstall hooks for Internet-o-metr

ys_ensure_script_file() {
	local path="$1"
	if [ ! -f "$path" ]; then
		cat >"$path" <<'EOF'
#!/bin/sh
EOF
		chmod 0755 "$path"
	fi
}

ys_add_hook() {
	local path="$1"
	local line="$2"

	ys_ensure_script_file "$path"
	if grep -qF "$HOOK_MARKER" "$path" 2>/dev/null; then
		return 0
	fi

	{
		echo ""
		echo "${HOOK_MARKER} start"
		echo "$line"
		echo "${HOOK_MARKER} end"
	} >>"$path"
}

ys_remove_hook() {
	local path="$1"
	[ -f "$path" ] || return 0

	awk -v start="${HOOK_MARKER} start" -v end="${HOOK_MARKER} end" '
		$0 == start { skip=1; next }
		$0 == end { skip=0; next }
		!skip { print }
	' "$path" >"${path}.${ADDON_TAG}.tmp" && mv "${path}.${ADDON_TAG}.tmp" "$path"
}

ys_ensure_hooks() {
	ys_add_hook /jffs/scripts/services-start \
		"[ -x ${ADDON_SCRIPT} ] && ${ADDON_SCRIPT} remount >/dev/null 2>&1 &"

	ys_add_hook /jffs/scripts/post-mount \
		"[ -x ${ADDON_SCRIPT} ] && ${ADDON_SCRIPT} remount >/dev/null 2>&1 &"

	ys_remove_hook /jffs/scripts/service-event
	ys_remove_hook /jffs/scripts/service-event-end

	ys_add_hook /jffs/scripts/service-event \
		"echo \"\$1\" | grep -q start && echo \"\$*\" | grep -q \"${ADDON_TAG}\" && [ -x ${ADDON_SCRIPT} ] && ${ADDON_SCRIPT} service_event \"\$@\" &"

	ys_add_hook /jffs/scripts/service-event-end \
		"[ \"\$1\" = \"stop\" ] && echo \"\$*\" | grep -q \"${ADDON_TAG}\" && [ -x ${ADDON_SCRIPT} ] && ${ADDON_SCRIPT} service_event \"\$@\" &"

	chmod 0755 /jffs/scripts/service-event /jffs/scripts/service-event-end \
		/jffs/scripts/services-start /jffs/scripts/post-mount 2>/dev/null
}

ys_strip_hook_marker() {
	local path="$1"
	local marker="$2"
	[ -f "$path" ] || return 0
	awk -v start="${marker} start" -v end="${marker} end" '
		$0 == start { skip=1; next }
		$0 == end { skip=0; next }
		!skip { print }
	' "$path" >"${path}.iom.tmp" && mv "${path}.iom.tmp" "$path"
}

ys_migrate_legacy_yandexspeed() {
	[ "$ADDON_TAG" = "internetometr" ] || return 0

	ys_strip_hook_marker /jffs/scripts/services-start "#yandexspeed"
	ys_strip_hook_marker /jffs/scripts/post-mount "#yandexspeed"
	ys_strip_hook_marker /jffs/scripts/service-event "#yandexspeed"
	ys_strip_hook_marker /jffs/scripts/service-event-end "#yandexspeed"

	if [ -f /tmp/menuTree.js ]; then
		grep -v 'tabName: "Yandex Speed"' /tmp/menuTree.js | \
			grep -v 'tabName: "Интернетометр"' >"/tmp/menuTree.iom.tmp" || true
		if [ -s /tmp/menuTree.iom.tmp ]; then
			mv /tmp/menuTree.iom.tmp /tmp/menuTree.js
		else
			rm -f /tmp/menuTree.iom.tmp
		fi
	fi

	rm -f /jffs/scripts/yandexspeed
	rm -rf /jffs/addons/yandexspeed /www/user/yandexspeed /tmp/yandexspeed
	for f in /www/user/user*.title; do
		[ -f "$f" ] || continue
		if grep -qx "yandexspeed" "$f" 2>/dev/null; then
			base=$(echo "$f" | sed 's/\.title$//')
			rm -f "$f" "${base}.asp"
		fi
	done
}

ys_install() {
	nvram get rc_support | grep -q am_addons
	if [ $? -ne 0 ]; then
		echo "Error: firmware does not support Merlin addons (am_addons)."
		return 5
	fi

	if ! ys_resolve_curl; then
		echo "Error: curl not found (checked /usr/sbin/curl, PATH)."
		echo "On the router run: ls -la /usr/sbin/curl; which curl; echo \$PATH"
		return 5
	fi
	echo "Using curl: $YS_CURL"

	if [ ! -f "${ADDON_DIR}/index.asp" ]; then
		echo "Error: addon files missing in ${ADDON_DIR}"
		return 5
	fi

	chmod 0755 "$ADDON_SCRIPT" "${ADDON_DIR}/run_speedtest.sh" 2>/dev/null
	chmod 0644 "${ADDON_DIR}/index.asp" "${ADDON_DIR}/internetometr.js" 2>/dev/null

	ys_migrate_legacy_yandexspeed
	ys_ensure_hooks
	ys_mount_ui
	echo "Internet-o-metr ${ADDON_VERSION} installed. Log out/in of WebUI, then open Adaptive QoS -> ${ADDON_TAB_NAME}."
	ys_log "Installed version ${ADDON_VERSION}"
	return 0
}

ys_uninstall() {
	if [ -f "$ADDON_LOCK" ]; then
		kill "$(cat "$ADDON_LOCK" 2>/dev/null)" 2>/dev/null
		rm -f "$ADDON_LOCK"
	fi

	ys_unmount_ui
	ys_remove_hook /jffs/scripts/services-start
	ys_remove_hook /jffs/scripts/post-mount
	ys_remove_hook /jffs/scripts/service-event
	ys_remove_hook /jffs/scripts/service-event-end

	rm -rf "$ADDON_TMP_DIR"
	rm -f "$ADDON_LOG"
	rm -rf "$ADDON_DIR"
	rm -f "$ADDON_SCRIPT"

	echo "Internet-o-metr uninstalled."
	ys_log "Uninstalled"
	return 0
}
