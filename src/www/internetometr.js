/* Internet-o-metr WebUI */
var Internetometr = (function () {
	var pollTimer = null;
	var elapsedTimer = null;
	var pollTicks = 0;
	var startedAt = 0;
	var sessionActive = false;
	var seenRunning = false;
	var STATUS_URL = "/user/internetometr/status.json";
	var RESULT_URL = "/user/internetometr/result.json";
	var LS_ENGINE = "ys_engine";
	var LS_SERVER = "ys_server_id";
	/* Embedded catalog: Merlin httpd often does not serve .list via XHR */
	var IPERF_SERVERS_RAW =
		"nsk_er|Сибирь и Дальний Восток|Новосибирск (ЭР-Телеком)|st.nsk.ertelecom.ru|5201-5209\n" +
		"krsk_er|Сибирь и Дальний Восток|Красноярск (ЭР-Телеком)|st.krsk.ertelecom.ru|5201-5207,5209\n" +
		"omsk_er|Сибирь и Дальний Восток|Омск (ЭР-Телеком)|st.omsk.ertelecom.ru|5201-5209\n" +
		"tomsk_er|Сибирь и Дальний Восток|Томск (ЭР-Телеком)|st.tomsk.ertelecom.ru|5201,5203-5209\n" +
		"barnaul_er|Сибирь и Дальний Восток|Барнаул (ЭР-Телеком)|st.barnaul.ertelecom.ru|5201-5202,5204-5209\n" +
		"irkutsk_er|Сибирь и Дальний Восток|Иркутск (ЭР-Телеком)|st.irkutsk.ertelecom.ru|5201-5209\n" +
		"nk_er|Сибирь и Дальний Восток|Новокузнецк (ЭР-Телеком)|st.nk.ertelecom.ru|5201-5209\n" +
		"ekat_er|Урал|Екатеринбург (ЭР-Телеком)|st.ekat.ertelecom.ru|5201-5209\n" +
		"tum_mts|Урал|Тюмень (МТС)|tumst.st.mtsws.net|3333\n" +
		"tmn_er|Урал|Тюмень (ЭР-Телеком)|st.tmn.ertelecom.ru|5201-5209\n" +
		"mgn_er|Урал|Челябинск / Магнитогорск (ЭР-Телеком)|st.mgn.ertelecom.ru|5201-5209\n" +
		"kurgan_er|Урал|Курган (ЭР-Телеком)|st.kurgan.ertelecom.ru|5201-5205,5207-5209\n" +
		"kaz_mts|Поволжье|Казань (МТС)|kazst.st.mtsws.net|3333\n" +
		"kzn_er|Поволжье|Казань (ЭР-Телеком)|st.kzn.ertelecom.ru|5201-5209\n" +
		"samara_er|Поволжье|Самара (ЭР-Телеком)|st.samara.ertelecom.ru|5201-5209\n" +
		"nn_er|Поволжье|Нижний Новгород (ЭР-Телеком)|st.nn.ertelecom.ru|5201-5209\n" +
		"nn_vtt|Поволжье|Нижний Новгород (ВолгаТелеком)|speed-nn.vtt.net|5201-5209\n" +
		"perm_er|Поволжье|Пермь (ЭР-Телеком)|st.perm.ertelecom.ru|5201-5205,5207-5209\n" +
		"saratov_er|Поволжье|Саратов (ЭР-Телеком)|st.saratov.ertelecom.ru|5201-5209\n" +
		"izhevsk_er|Поволжье|Ижевск (ЭР-Телеком)|st.izhevsk.ertelecom.ru|5201-5209\n" +
		"oren_er|Поволжье|Оренбург (ЭР-Телеком)|st.oren.ertelecom.ru|5201-5209\n" +
		"penza_er|Поволжье|Пенза (ЭР-Телеком)|st.penza.ertelecom.ru|5201-5209\n" +
		"kirov_er|Поволжье|Киров (ЭР-Телеком)|st.kirov.ertelecom.ru|5201-5209\n" +
		"chelny_er|Поволжье|Набережные Челны (ЭР-Телеком)|st.chelny.ertelecom.ru|5201-5209\n" +
		"yola_er|Поволжье|Йошкар-Ола (ЭР-Телеком)|st.yola.ertelecom.ru|5201-5209\n" +
		"msk_hostkey|Центр и Северо-Запад|Москва (Hostkey)|spd-rudp.hostkey.ru|5201-5209\n" +
		"spb_er|Центр и Северо-Запад|Санкт-Петербург (ЭР-Телеком)|st.spb.ertelecom.ru|5201-5209\n" +
		"ryazan_er|Центр и Северо-Запад|Рязань (ЭР-Телеком)|st.ryazan.ertelecom.ru|5201-5209\n" +
		"tula_er|Центр и Северо-Запад|Тула (ЭР-Телеком)|st.tula.ertelecom.ru|5201-5209\n" +
		"tver_er|Центр и Северо-Запад|Тверь (ЭР-Телеком)|st.tver.ertelecom.ru|5201-5209\n" +
		"kursk_er|Центр и Северо-Запад|Курск (ЭР-Телеком)|st.kursk.ertelecom.ru|5201-5209\n" +
		"lipetsk_er|Центр и Северо-Запад|Липецк (ЭР-Телеком)|st.lipetsk.ertelecom.ru|5201-5209\n" +
		"bryansk_er|Центр и Северо-Запад|Брянск (ЭР-Телеком)|st.bryansk.ertelecom.ru|5201-5209\n" +
		"rostov_er|Юг|Ростов-на-Дону (ЭР-Телеком)|st.rostov.ertelecom.ru|5201-5209\n" +
		"volgograd_er|Юг|Волгоград (ЭР-Телеком)|st.volgograd.ertelecom.ru|5201-5209\n";

	var PHASE_MAP = {
		start: "probes",
		probes: "probes",
		ip: "probes",
		download: "download",
		upload: "upload",
		ping: "ping",
		done: "ping"
	};

	function $(id) {
		return document.getElementById(id);
	}

	function setText(id, value) {
		var el = $(id);
		if (el) el.innerHTML = value;
	}

	function setBusy(busy) {
		var btn = $("ys_btn");
		var wrap = $("ys_progress_wrap");
		var eng = $("ys_engine");
		var sel = $("ys_server_sel");
		if (btn) {
			btn.disabled = busy;
			btn.value = busy ? "Идёт измерение..." : "Измерить";
		}
		if (eng) eng.disabled = busy;
		if (sel) sel.disabled = busy;
		if (wrap) wrap.style.display = busy ? "block" : "none";
	}

	function setProgress(pct) {
		var fill = $("ys_progress_fill");
		if (!fill) return;
		if (pct < 0) pct = 0;
		if (pct > 100) pct = 100;
		fill.style.width = pct + "%";
	}

	function highlightPhase(phase) {
		var key = PHASE_MAP[phase] || phase;
		var ids = ["probes", "download", "upload", "ping"];
		var i, el;
		for (i = 0; i < ids.length; i++) {
			el = $("ys_ph_" + ids[i]);
			if (el) el.className = ids[i] === key ? "ys_phase_on" : "";
		}
	}

	function startElapsed() {
		stopElapsed();
		startedAt = new Date().getTime();
		elapsedTimer = setInterval(function () {
			var sec = Math.floor((new Date().getTime() - startedAt) / 1000);
			setText("ys_elapsed", "(" + sec + " с)");
		}, 500);
	}

	function stopElapsed() {
		if (elapsedTimer) {
			clearInterval(elapsedTimer);
			elapsedTimer = null;
		}
	}

	function endSession() {
		sessionActive = false;
		seenRunning = false;
		setBusy(false);
		stopPoll();
		stopElapsed();
	}

	function formatServerLine(data) {
		if (!data) return "-";
		if (data.engine === "iperf" || data.source === "iperf3") {
			var name = data.server || data.host || "iperf";
			var hp = data.host || "";
			var port = data.port ? String(data.port) : "";
			if (hp && port) return name + " - " + hp + ":" + port;
			if (hp) return name + " - " + hp;
			return name;
		}
		if (data.source) return data.source;
		return "Yandex CDN";
	}

	function applyMetrics(data) {
		setText("ys_ipv4", data.ipv4 || "-");
		setText("ys_ping", data.ping_ms != null ? data.ping_ms : "-");
		setText("ys_download", data.download_mbps != null ? data.download_mbps : "-");
		setText("ys_upload", data.upload_mbps != null ? data.upload_mbps : "-");
		setText("ys_server", formatServerLine(data));
		if (data.time) setText("ys_time", data.time);
	}

	function applyPayload(data) {
		if (!data) return;

		if (sessionActive && !seenRunning) {
			if (data.state === "done") return;
			if (data.state === "error") return;
		}

		if (data.state === "running") {
			seenRunning = true;
			setText("ys_status", data.message || ("Этап: " + (data.phase || "...")));
			if (data.progress != null) setProgress(data.progress);
			highlightPhase(data.phase);
			if (data.ipv4) setText("ys_ipv4", data.ipv4);
			if (data.ping_ms != null) setText("ys_ping", data.ping_ms);
			if (data.download_mbps != null) setText("ys_download", data.download_mbps);
			if (data.upload_mbps != null) setText("ys_upload", data.upload_mbps);
			if (data.server || data.host || data.port) setText("ys_server", formatServerLine(data));
			setBusy(true);
			return;
		}

		if (data.state === "error") {
			setText("ys_status", "Ошибка: " + (data.message || "unknown"));
			setProgress(0);
			endSession();
			return;
		}

		if (data.state === "done") {
			if (sessionActive && !seenRunning) return;
			setText("ys_status", "Готов к замеру");
			setProgress(100);
			highlightPhase("done");
			applyMetrics(data);
			endSession();
			setTimeout(function () {
				var wrap = $("ys_progress_wrap");
				if (wrap) wrap.style.display = "none";
			}, 2500);
		}
	}

	function fetchText(url, cb, errCb) {
		var xhr = new XMLHttpRequest();
		xhr.open("GET", url + "?_=" + new Date().getTime(), true);
		xhr.onreadystatechange = function () {
			if (xhr.readyState !== 4) return;
			if (xhr.status >= 200 && xhr.status < 300) {
				cb(xhr.responseText || "");
			} else if (errCb) {
				errCb(xhr.status);
			}
		};
		xhr.send(null);
	}

	function fetchJson(url, cb, errCb) {
		fetchText(url, function (txt) {
			if (!txt) return;
			try {
				cb(JSON.parse(txt));
			} catch (e) {}
		}, errCb);
	}

	function parseServersList(text) {
		var lines = text.split(/\r?\n/);
		var i, line, parts, groups = {}, order = [];
		for (i = 0; i < lines.length; i++) {
			line = lines[i].replace(/^\s+|\s+$/g, "");
			if (!line || line.charAt(0) === "#") continue;
			parts = line.split("|");
			if (parts.length < 5) continue;
			if (!groups[parts[1]]) {
				groups[parts[1]] = [];
				order.push(parts[1]);
			}
			groups[parts[1]].push({
				id: parts[0],
				region: parts[1],
				label: parts[2],
				host: parts[3],
				ports: parts[4]
			});
		}
		return { groups: groups, order: order };
	}

	function fillServerSelect(parsed) {
		var sel = $("ys_server_sel");
		var saved, g, j, opt, list, html, i;
		if (!sel) return;
		saved = null;
		try {
			saved = localStorage.getItem(LS_SERVER);
		} catch (e) {}

		if (sel.options && sel.options.length > 1) {
			if (saved) {
				for (i = 0; i < sel.options.length; i++) {
					if (sel.options[i].value === saved) {
						sel.selectedIndex = i;
						break;
					}
				}
			}
			return;
		}

		if (!parsed) return;
		html = [];
		for (g = 0; g < parsed.order.length; g++) {
			list = parsed.groups[parsed.order[g]];
			for (j = 0; j < list.length; j++) {
				html.push(
					'<option value="' + list[j].id + '"' +
					((saved && saved === list[j].id) ? " selected" : "") +
					">" + parsed.order[g] + " - " + list[j].label + "</option>"
				);
			}
		}
		sel.innerHTML = html.join("");
		if (!sel.value && sel.options.length) sel.selectedIndex = 0;
	}

	function onEngineChange() {
		var eng = $("ys_engine");
		var row = $("ys_server_row");
		var mode = eng ? eng.value : "yandex";
		if (row) row.style.display = mode === "iperf" ? "" : "none";
		try {
			localStorage.setItem(LS_ENGINE, mode);
		} catch (e) {}
	}

	function buildAmngCustom() {
		var eng = $("ys_engine");
		var sel = $("ys_server_sel");
		var mode = eng ? eng.value : "yandex";
		var sid = sel && sel.value ? sel.value : "nsk_er";
		if (mode === "iperf") {
			try {
				localStorage.setItem(LS_SERVER, sid);
			} catch (e) {}
			return "iperf:" + sid;
		}
		return "yandex";
	}

	function pollOnce() {
		pollTicks += 1;
		fetchJson(STATUS_URL, applyPayload, function () {
			if (pollTicks === 10) {
				setText("ys_status", "Ожидание ответа роутера...");
			}
			if (pollTicks > 150) {
				setText("ys_status", "Таймаут ожидания (iperf обычно 30-60 с)");
				endSession();
			}
		});
	}

	function startPoll() {
		stopPoll();
		pollTicks = 0;
		pollTimer = setInterval(pollOnce, 800);
		pollOnce();
	}

	function stopPoll() {
		if (pollTimer) {
			clearInterval(pollTimer);
			pollTimer = null;
		}
	}

	function neutralizeMerlinApplyUi() {
		if (typeof hideLoading === "function") hideLoading();
		var loading = document.getElementById("Loading");
		if (loading) {
			loading.style.visibility = "hidden";
			loading.style.display = "none";
		}
	}

	function triggerSpeedtest() {
		var page = window.location.pathname.substring(1);
		var eng = $("ys_engine");
		var sel = $("ys_server_sel");
		var mode = eng && eng.value ? eng.value : "yandex";
		var sid = sel && sel.value ? sel.value : "nsk_er";
		var script = "restart_internetometr";
		var req;
		var amng = $("amng_custom");

		sid = String(sid).replace(/[^A-Za-z0-9_]/g, "");
		if (!sid) sid = "nsk_er";

		if (mode === "iperf") {
			script = "restart_internetometr_iperf_" + sid;
			req = "iperf:" + sid;
			try {
				localStorage.setItem(LS_SERVER, sid);
			} catch (e) {}
		} else {
			req = "yandex";
		}

		if (amng) amng.value = req;
		if (document.form && document.form.amng_custom) {
			document.form.amng_custom.value = req;
		}

		document.form.action_script.value = script;
		document.form.action_mode.value = "apply";
		document.form.action_wait.value = "9999";
		document.form.current_page.value = page;
		document.form.next_page.value = page;
		document.form.target = "hidden_frame";
		document.form.action = "/start_apply.htm";
		document.form.method = "post";
		document.form.submit();

		var n = 0;
		var killLoad = setInterval(function () {
			neutralizeMerlinApplyUi();
			n += 1;
			if (n >= 20) clearInterval(killLoad);
		}, 400);
	}

	function start() {
		if (sessionActive) return;

		sessionActive = true;
		seenRunning = false;
		setBusy(true);
		setProgress(2);
		highlightPhase("probes");
		setText("ys_status", "Запуск замера на роутере...");
		setText("ys_download", "-");
		setText("ys_upload", "-");
		setText("ys_ping", "-");
		setText("ys_ipv4", "-");
		setText("ys_server", "-");
		setText("ys_time", "-");

		startElapsed();
		startPoll();
		triggerSpeedtest();
	}

	function init() {
		var eng = $("ys_engine");
		var saved;

		try {
			saved = localStorage.getItem(LS_ENGINE);
		} catch (e) {
			saved = null;
		}
		if (eng && saved) eng.value = saved;

		fillServerSelect(parseServersList(IPERF_SERVERS_RAW));
		onEngineChange();

		fetchJson(RESULT_URL, function (data) {
			if (data && data.state === "done") applyPayload(data);
		});
		fetchJson(STATUS_URL, function (data) {
			if (data && data.state === "running") {
				sessionActive = true;
				seenRunning = true;
				setBusy(true);
				startElapsed();
				startPoll();
			}
		});
	}

	return {
		init: init,
		start: start,
		onEngineChange: onEngineChange
	};
})();
