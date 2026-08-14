<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge">
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta HTTP-EQUIV="Pragma" CONTENT="no-cache">
<meta HTTP-EQUIV="Expires" CONTENT="-1">
<!--page:internetometr-->
<link rel="shortcut icon" href="images/favicon.png">
<link rel="icon" href="images/favicon.png">
<title>Интернетометр</title>
<link rel="stylesheet" type="text/css" href="index_style.css">
<link rel="stylesheet" type="text/css" href="form_style.css">
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>
<script type="text/javascript" src="/user/internetometr/internetometr.js?v=1200"></script>
<style type="text/css">
#ys_progress_wrap { margin: 12px 0 8px 0; display: none; }
#ys_progress_bar {
	height: 14px; background: #2F3A3E; border: 1px solid #6B8FA3;
	border-radius: 2px; overflow: hidden;
}
#ys_progress_fill {
	height: 100%; width: 0%; background: #FC0;
	transition: width 0.4s ease;
}
#ys_phases { margin: 8px 0 0 0; color: #A4B7C4; font-size: 12px; }
#ys_phases .ys_phase_on { color: #FC0; font-weight: bold; }
#ys_elapsed { color: #FFCC66; margin-left: 8px; }
.ys_big { font-size: 22px; font-weight: bold; color: #FFF; }
</style>
<script type="text/javascript">
function initial(){
	SetCurrentPage();
	show_menu();
	Internetometr.init();
}

function SetCurrentPage(){
	document.form.next_page.value = window.location.pathname.substring(1);
	document.form.current_page.value = window.location.pathname.substring(1);
}

function startInternetometr(){
	Internetometr.start();
}

function ysEngineChanged(){
	Internetometr.onEngineChange();
}
</script>
</head>
<body onload="initial();" class="bg">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>
<form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">
<input type="hidden" name="current_page" value="">
<input type="hidden" name="next_page" value="">
<input type="hidden" name="group_id" value="">
<input type="hidden" name="modified" value="0">
<input type="hidden" name="action_mode" value="apply">
<input type="hidden" name="action_script" value="restart_internetometr">
<input type="hidden" name="action_wait" value="1">
<input type="hidden" name="first_time" value="">
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>">
<input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>">
<input type="hidden" name="amng_custom" id="amng_custom" value="">

<table class="content" align="center" cellpadding="0" cellspacing="0">
<tr>
<td width="17">&nbsp;</td>
<td valign="top" width="202">
<div id="mainMenu"></div>
<div id="subMenu"></div>
</td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>
<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
<tr>
<td align="left" valign="top">
<table width="760px" border="0" cellpadding="5" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle" id="FormTitle">
<tr bgcolor="#4D595D" valign="top">
<td>
<div>&nbsp;</div>
<div class="formfonttitle">Интернетометр</div>
<div style="margin:10px 0 10px 5px;" class="splitLine"></div>
<div class="formfontdesc" id="ys_desc">
Проверка скорости WAN на роутере: Яндекс Интернетометр или прямой iperf3 к региональным серверам.
</div>

<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" style="margin-bottom:12px;">
<thead>
<tr><td colspan="2">Параметры</td></tr>
</thead>
<tr>
<th width="40%">Режим</th>
<td>
<select id="ys_engine" class="input_option" onchange="ysEngineChanged();">
<option value="yandex">Yandex (Интернетометр)</option>
<option value="iperf">iPerf3 (регионы)</option>
</select>
</td>
</tr>
<tr id="ys_server_row" style="display:none;">
<th>Сервер</th>
<td>
<select id="ys_server_sel" class="input_option" style="width:420px;">
<option value="nsk_er">Сибирь и Дальний Восток - Новосибирск (ЭР-Телеком)</option>
<option value="krsk_er">Сибирь и Дальний Восток - Красноярск (ЭР-Телеком)</option>
<option value="omsk_er">Сибирь и Дальний Восток - Омск (ЭР-Телеком)</option>
<option value="tomsk_er">Сибирь и Дальний Восток - Томск (ЭР-Телеком)</option>
<option value="barnaul_er">Сибирь и Дальний Восток - Барнаул (ЭР-Телеком)</option>
<option value="irkutsk_er">Сибирь и Дальний Восток - Иркутск (ЭР-Телеком)</option>
<option value="nk_er">Сибирь и Дальний Восток - Новокузнецк (ЭР-Телеком)</option>
<option value="ekat_er">Урал - Екатеринбург (ЭР-Телеком)</option>
<option value="tum_mts">Урал - Тюмень (МТС)</option>
<option value="tmn_er">Урал - Тюмень (ЭР-Телеком)</option>
<option value="mgn_er">Урал - Челябинск / Магнитогорск (ЭР-Телеком)</option>
<option value="kurgan_er">Урал - Курган (ЭР-Телеком)</option>
<option value="kaz_mts">Поволжье - Казань (МТС)</option>
<option value="kzn_er">Поволжье - Казань (ЭР-Телеком)</option>
<option value="samara_er">Поволжье - Самара (ЭР-Телеком)</option>
<option value="nn_er">Поволжье - Нижний Новгород (ЭР-Телеком)</option>
<option value="nn_vtt">Поволжье - Нижний Новгород (ВолгаТелеком)</option>
<option value="perm_er">Поволжье - Пермь (ЭР-Телеком)</option>
<option value="saratov_er">Поволжье - Саратов (ЭР-Телеком)</option>
<option value="izhevsk_er">Поволжье - Ижевск (ЭР-Телеком)</option>
<option value="oren_er">Поволжье - Оренбург (ЭР-Телеком)</option>
<option value="penza_er">Поволжье - Пенза (ЭР-Телеком)</option>
<option value="kirov_er">Поволжье - Киров (ЭР-Телеком)</option>
<option value="chelny_er">Поволжье - Набережные Челны (ЭР-Телеком)</option>
<option value="yola_er">Поволжье - Йошкар-Ола (ЭР-Телеком)</option>
<option value="msk_hostkey">Центр и Северо-Запад - Москва (Hostkey)</option>
<option value="spb_er">Центр и Северо-Запад - Санкт-Петербург (ЭР-Телеком)</option>
<option value="ryazan_er">Центр и Северо-Запад - Рязань (ЭР-Телеком)</option>
<option value="tula_er">Центр и Северо-Запад - Тула (ЭР-Телеком)</option>
<option value="tver_er">Центр и Северо-Запад - Тверь (ЭР-Телеком)</option>
<option value="kursk_er">Центр и Северо-Запад - Курск (ЭР-Телеком)</option>
<option value="lipetsk_er">Центр и Северо-Запад - Липецк (ЭР-Телеком)</option>
<option value="bryansk_er">Центр и Северо-Запад - Брянск (ЭР-Телеком)</option>
<option value="rostov_er">Юг - Ростов-на-Дону (ЭР-Телеком)</option>
<option value="volgograd_er">Юг - Волгоград (ЭР-Телеком)</option>
</select>
<div style="margin-top:4px;color:#A4B7C4;font-size:11px;">Если порт занят или недоступен, будет выбран следующий из диапазона сервера.</div>
</td>
</tr>
</table>

<div id="ys_progress_wrap">
	<div id="ys_progress_bar"><div id="ys_progress_fill"></div></div>
	<div id="ys_phases">
		<span id="ys_ph_probes">Серверы</span> ->
		<span id="ys_ph_download">Входящая</span> ->
		<span id="ys_ph_upload">Исходящая</span> ->
		<span id="ys_ph_ping">Ping</span>
		<span id="ys_elapsed"></span>
	</div>
</div>

<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
<thead>
<tr><td colspan="2">Результаты</td></tr>
</thead>
<tr>
<th width="40%">Статус</th>
<td><span id="ys_status">Готов к замеру</span></td>
</tr>
<tr>
<th>Входящая (Download)</th>
<td><span id="ys_download" class="ys_big">-</span> Mbps</td>
</tr>
<tr>
<th>Исходящая (Upload)</th>
<td><span id="ys_upload" class="ys_big">-</span> Mbps</td>
</tr>
<tr>
<th>Задержка (Ping)</th>
<td><span id="ys_ping" class="ys_big">-</span> ms</td>
</tr>
<tr>
<th>Сервер / порт</th>
<td><span id="ys_server">-</span></td>
</tr>
<tr>
<th>IPv4</th>
<td><span id="ys_ipv4">-</span></td>
</tr>
<tr>
<th>Время замера</th>
<td><span id="ys_time">-</span></td>
</tr>
</table>

<div class="apply_gen" style="margin-top:15px;">
<input type="button" id="ys_btn" class="button_gen" onclick="startInternetometr();" value="Измерить">
</div>

</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
<td width="10" align="center" valign="top"></td>
</tr>
</table>
</form>
<div id="footer"></div>
</body>
</html>
