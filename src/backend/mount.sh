#!/bin/sh
# WebUI mount / unmount for Internet-o-metr

# BusyBox [ -f ] is false for symlinks, so Merlin am_get_webui_page treats
# occupied slots (e.g. XrayUI -> user1.asp) as free and overwrites them.
# Always treat -e / -L as occupied; identify our page by marker or target.

ys_page_is_ours() {
	local page_path="$1"
	local target

	[ -e "$page_path" ] || [ -L "$page_path" ] || return 1

	if grep -q "page:${ADDON_TAG}" "$page_path" 2>/dev/null; then
		return 0
	fi

	if [ -L "$page_path" ]; then
		target=$(readlink "$page_path" 2>/dev/null)
		case "$target" in
			*"/${ADDON_TAG}/index.asp") return 0 ;;
		esac
	fi
	return 1
}

ys_page_is_taken() {
	local page_path="$1"
	[ -e "$page_path" ] || [ -L "$page_path" ]
}

ys_get_webui_page() {
	ADDON_USER_PAGE="none"
	local i page path saved

	# Remembered slot from previous mount
	saved=""
	if [ -f "${ADDON_DIR}/webui_page" ]; then
		saved=$(cat "${ADDON_DIR}/webui_page" 2>/dev/null | tr -d '\r\n')
	fi
	if [ -n "$saved" ] && ys_page_is_ours "/www/user/${saved}"; then
		ADDON_USER_PAGE="$saved"
		return 0
	fi

	# Already mounted under any userN.asp
	i=1
	while [ "$i" -le 20 ]; do
		page="user${i}.asp"
		path="/www/user/${page}"
		if ys_page_is_ours "$path"; then
			ADDON_USER_PAGE="$page"
			return 0
		fi
		i=$((i + 1))
	done

	# First free slot (symlink counts as occupied)
	i=1
	while [ "$i" -le 20 ]; do
		page="user${i}.asp"
		path="/www/user/${page}"
		if ! ys_page_is_taken "$path"; then
			ADDON_USER_PAGE="$page"
			return 0
		fi
		i=$((i + 1))
	done

	return 1
}

ys_save_webui_page() {
	[ -n "$ADDON_USER_PAGE" ] && [ "$ADDON_USER_PAGE" != "none" ] || return 0
	echo "$ADDON_USER_PAGE" >"${ADDON_DIR}/webui_page"
}

ys_bind_menutree() {
	if [ ! -f /tmp/menuTree.js ]; then
		cp /www/require/modules/menuTree.js /tmp/menuTree.js
		mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
	fi
}

ys_remount_menutree() {
	umount /www/require/modules/menuTree.js 2>/dev/null
	mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
}

ys_insert_menu_tab() {
	local page="$1"
	local tmp="/tmp/menuTree.${ADDON_TAG}.$$"
	local mode="bandwidth"

	# Idempotent: drop previous entries for this tab (incl. legacy English name) or this url
	grep -v "tabName: \"${ADDON_TAB_NAME}\"" /tmp/menuTree.js 2>/dev/null | \
		grep -v 'tabName: "Yandex Speed"' | \
		grep -v "url: \"${page}\"" >"$tmp" 2>/dev/null || cp /tmp/menuTree.js "$tmp"

	if grep -q "AdaptiveQoS_InternetSpeed.asp" "$tmp"; then
		mode="internetspeed"
	elif grep -q 'index: "menu_BandwidthMonitor"' "$tmp"; then
		mode="bandwidth"
	else
		mode="tools"
	fi

	awk -v page="$page" -v tab="$ADDON_TAB_NAME" -v mode="$mode" '
		BEGIN { insec=0; done=0 }
		mode=="internetspeed" && /AdaptiveQoS_InternetSpeed\.asp/ && !done {
			print
			print "{url: \"" page "\", tabName: \"" tab "\"},"
			done=1
			next
		}
		mode=="bandwidth" && /index: "menu_BandwidthMonitor"/ { insec=1 }
		mode=="bandwidth" && insec && /index: "/ && !/menu_BandwidthMonitor/ { insec=0 }
		mode=="bandwidth" && insec && /url: "NULL"/ && /__INHERIT__/ && !done {
			print "{url: \"" page "\", tabName: \"" tab "\"},"
			done=1
		}
		mode=="tools" && /Tools_OtherSettings\.asp/ && !done {
			print
			print "{url: \"" page "\", tabName: \"" tab "\"},"
			done=1
			next
		}
		{ print }
	' "$tmp" >"${tmp}.2" && mv "${tmp}.2" /tmp/menuTree.js
	rm -f "$tmp"
}

ys_mount_ui() {
	nvram get rc_support | grep -q am_addons
	if [ $? -ne 0 ]; then
		ys_log "Firmware does not support am_addons"
		return 5
	fi

	ys_migrate_legacy_yandexspeed

	ys_get_webui_page || {
		ys_log "No free WebUI page slot"
		return 5
	}

	ys_log "Mounting UI as $ADDON_USER_PAGE"

	ys_ensure_hooks

	ln -sf "${ADDON_DIR}/index.asp" "/www/user/${ADDON_USER_PAGE}"
	# Tag for Merlin addon discovery; visible tab name comes from menuTree tabName
	echo "$ADDON_TAG" >"/www/user/$(echo "$ADDON_USER_PAGE" | cut -f1 -d'.').title"
	ys_save_webui_page

	mkdir -p "$ADDON_WEB_DIR"
	ln -sf "${ADDON_DIR}/internetometr.js" "${ADDON_WEB_DIR}/internetometr.js"
	ln -sf "${ADDON_DIR}/iperf_servers.list" "${ADDON_WEB_DIR}/iperf_servers.list" 2>/dev/null
	ys_ensure_tmp
	rm -f "${ADDON_WEB_DIR}/data"

	ys_bind_menutree
	ys_insert_menu_tab "$ADDON_USER_PAGE"
	ys_remount_menutree

	ys_log "UI mounted successfully"
	return 0
}

ys_unmount_ui() {
	local page path base

	nvram get rc_support | grep -q am_addons
	if [ $? -ne 0 ]; then
		return 0
	fi

	# Only remove OUR slot - never a "free" guess that might be XrayUI
	ADDON_USER_PAGE="none"
	ys_get_webui_page
	page="$ADDON_USER_PAGE"
	if [ -n "$page" ] && [ "$page" != "none" ] && ys_page_is_ours "/www/user/${page}"; then
		ys_log "Unmounting UI $page"
		base=$(echo "$page" | cut -f1 -d'.')
		rm -f "/www/user/${page}"
		rm -f "/www/user/${base}.title"
	else
		ys_log "No owned WebUI page to unmount"
	fi
	rm -f "${ADDON_DIR}/webui_page"

	rm -rf "$ADDON_WEB_DIR"

	if [ -f /tmp/menuTree.js ]; then
		grep -v "tabName: \"${ADDON_TAB_NAME}\"" /tmp/menuTree.js | \
			grep -v 'tabName: "Yandex Speed"' >"/tmp/menuTree.${ADDON_TAG}.tmp"
		mv "/tmp/menuTree.${ADDON_TAG}.tmp" /tmp/menuTree.js
		ys_remount_menutree
	fi

	ys_log "UI unmounted"
	return 0
}

ys_remount_ui() {
	ys_unmount_ui
	sleep 1
	ys_mount_ui
}
