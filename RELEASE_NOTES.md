# Internet-o-metr v1.1.0

Режим **iPerf3** с выбором регионального сервера (ЭР-Телеком / МТС / Hostkey и др.), плюс замер через Яндекс. Пути и CLI: `internetometr`.

## Summary

- два движка в одной вкладке: **Yandex** и **iPerf3**
- каталог серверов по регионам РФ; перебор портов при refuse/busy
- DL (`iperf3 -R`) + UL + ICMP ping
- Yandex без Entware; для iPerf нужен `opkg install iperf3`
- хуки `#internetometr`, сервис `restart_internetometr`

## Что в архиве

Файл релиза: **`asuswrt-merlin-internetometr.tar.gz`**

| Файл | Роль |
|------|------|
| `internetometr` | CLI → `/jffs/scripts/` |
| `_globals.sh` | пути, версия **1.1.0** |
| `install.sh` / `mount.sh` | хуки и вкладка |
| `run_speedtest.sh` | движок Yandex |
| `run_iperf.sh` / `iperf_servers.sh` / `iperf_servers.list` | движок iPerf + каталог |
| `index.asp` / `internetometr.js` | WebUI |

## Установка / обновление

```sh
cd /tmp
rm -rf /jffs/addons/internetometr
tar -xzf asuswrt-merlin-internetometr.tar.gz -C /jffs/addons
mv /jffs/addons/internetometr/internetometr /jffs/scripts/internetometr
chmod 0755 /jffs/scripts/internetometr
sh /jffs/scripts/internetometr install
```

iPerf:

```sh
opkg update && opkg install iperf3
```

Logout/login → Adaptive QoS → Интернетометр.

## CLI

```sh
/jffs/scripts/internetometr run
/jffs/scripts/internetometr run iperf nsk_er
```

## Известные ограничения

- публичные iperf-серверы: один тест на порт; при busy берётся следующий
- без `iperf3` iPerf-режим пишет ошибку в UI
- ICMP может быть закрыт на стороне сервера

## Test plan

- [ ] Yandex-режим: DL/UL/ping как раньше
- [ ] iPerf: выбор Новосибирска → порт при busy меняется → цифры в UI
- [ ] Без iperf3: понятная ошибка, polling не зависает
- [ ] XrayUI / чужой `userN.asp` не затирается
- [ ] `uninstall` чистит хуки `#internetometr`

---

**Не связан с Яндексом и ASUS. Используйте на свой страх и риск.**
