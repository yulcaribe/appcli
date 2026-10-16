-- YulCaribe H298A WiFi Repeater v0.3
-- Built for stock CGI/Lua page loader. No dependency on new menu permissions.
local html = [=[
<div class="instCfgArea" id="YCRepeaterRoot">
  <div class="HeadDIV">
    <h1 class="collapBar">WiFi Repeater <small style="font-size:12px">YulCaribe v0.3 (RAM Test)</small></h1>
    <div class="formTblWrap"><div class="formTbl">
      <p style="padding:8px;border:1px solid #d7d7d7;max-width:850px;line-height:1.5">
        Bu panel dogrudan MediaTek Wi-Fi surucusuyle calisir. Bu paket MTD'ye dogrudan yazmaz; ZTE'nin setmode komutu
        kendi yapilandirmasini degistirebilir. Ethernet ile bagliyken deneyin.
        STA/AP istemci destegi firmware'e gore degisir. STA baglantisi kuruldu mesaji,
        tek basina Internet/LAN paylasiminin calistigi anlamina gelmez.
      </p>
      <div style="margin:12px 0;padding:12px;border:1px solid #ddd;max-width:860px">
        <h3>1. Mevcut Durum ve Calisma Modu</h3>
        <p>ZTE NetSphere rolu: <b id="ycRole">-</b> &nbsp; MultiAP: <b id="ycEnabled">-</b></p>
        <p>Yayindaki ana SSID'ler: <b id="ycCurrentAP2">-</b> (2.4 GHz) / <b id="ycCurrentAP5">-</b> (5 GHz)</p>
        <div class="buttongroup">
          <input class="Button" id="ycRefresh" type="button" value="Durumu Yenile" />
          <input class="Button" id="ycFullStatus" type="button" value="WorkMode / LAN Durumu" />
          <input class="Button" id="ycMode7" type="button" value="Repeater Modu 7 (deneysel)" />
          <input class="Button" id="ycConfirmMode" type="button" value="Modu Onayla" />
          <input class="Button" id="ycMode1" type="button" value="Eski Mod 1'e Don" />
        </div>
        <p style="font-size:12px">Mod 7 denemesinde 180 saniyelik otomatik geri donus kurulur.
        Yalnizca erisiminiz devam ediyorsa "Modu Onayla" tusuna basin.
        Bu geri alma <b>kesin kurtarma garantisi degildir.</b></p>
      </div>
      <div style="margin:12px 0;padding:12px;border:1px solid #ddd;max-width:860px">
        <h3>2. Ana Wi-Fi Agini Tara ve Baglan</h3>
        <div class="buttongroup">
          <input class="Button" id="ycScan2" type="button" value="2.4 GHz Tara" />
          <input class="Button" id="ycScan5" type="button" value="5 GHz Tara" />
        </div>
        <p>Gorunen aglardan birini secin veya SSID'yi elle yazin:</p>
        <p>
          <select id="ycScanResults" style="max-width:420px;min-width:260px">
            <option value="">Tarama yapilmadi</option>
          </select>
          <span id="ycScanCount"></span>
        </p>
        <div class="row"><label class="left w200">Uplink bant</label>
          <div class="right"><select id="ycStaBand"><option value="2g">2.4 GHz</option><option value="5g">5 GHz</option></select></div></div>
        <div class="row"><label class="left w200">Ana Wi-Fi SSID</label>
          <div class="right"><input id="ycStaSSID" type="text" maxlength="32" style="width:290px" autocomplete="off" /></div></div>
        <div class="row"><label class="left w200">Ana Wi-Fi Parola</label>
          <div class="right"><input id="ycStaKey" type="password" maxlength="63" style="width:290px" autocomplete="new-password" /></div></div>
        <div class="buttongroup" style="margin-top:8px">
          <input class="Button" id="ycConnect" type="button" value="STA Baglantisini Dene" />
        </div>
        <p style="font-size:12px">WPA2-PSK/AES profil denemesi. Bu firmware'de ApCli destegi
        yoksa surucu hatasi gorunur; baglanti kurulmus gibi gosterilmez.</p>
        <pre id="ycScanRaw" style="white-space:pre;overflow:auto;max-height:180px;background:#f6f6f6;padding:8px;border:1px solid #ddd">Tarama sonucu burada gorunecek.</pre>
      </div>
      <div style="margin:12px 0;padding:12px;border:1px solid #ddd;max-width:860px">
        <h3>3. Wi-Fi Yayini (AP)</h3>
        <p>Iki bandin yayin adini ve sifresini birbirinden bagimsiz ayarlayabilirsiniz.
        Yalnizca gecici surucu ayari uygulanir; ZTE konfigurasyonuna kaydedilmez.</p>
        <h4>2.4 GHz</h4>
        <div class="row"><label class="left w200">Yayin SSID</label>
          <div class="right"><input id="ycAP2SSID" type="text" maxlength="32" style="width:290px" /></div></div>
        <div class="row"><label class="left w200">WPA2 parola</label>
          <div class="right"><input id="ycAP2Key" type="password" maxlength="63" style="width:290px" autocomplete="new-password" /></div></div>
        <div class="buttongroup">
          <input class="Button" id="ycPublish2" type="button" value="2.4 GHz SSID/Sifre Uygula" />
          <input class="Button" id="ycAP2On" type="button" value="2.4 GHz Yayin Ac" />
          <input class="Button" id="ycAP2Off" type="button" value="2.4 GHz Yayin Kapat (90 sn)" />
        </div>
        <h4>5 GHz</h4>
        <div class="row"><label class="left w200">Yayin SSID</label>
          <div class="right"><input id="ycAP5SSID" type="text" maxlength="32" style="width:290px" /></div></div>
        <div class="row"><label class="left w200">WPA2 parola</label>
          <div class="right"><input id="ycAP5Key" type="password" maxlength="63" style="width:290px" autocomplete="new-password" /></div></div>
        <div class="buttongroup">
          <input class="Button" id="ycPublish5" type="button" value="5 GHz SSID/Sifre Uygula" />
          <input class="Button" id="ycAP5On" type="button" value="5 GHz Yayin Ac" />
          <input class="Button" id="ycAP5Off" type="button" value="5 GHz Yayin Kapat (90 sn)" />
        </div>
        <p style="font-size:12px">"Yayin Kapat" ayni bandin kablosuz istemci baglantisini da kesebilir.
          Her kapatmadan 90 saniye sonra arayuz otomatik yeniden acilir.</p>
      </div>
      <div style="margin:12px 0;padding:12px;border:1px solid #ddd;max-width:860px">
        <h3>4. LAN Paylasimi</h3>
        <p>LAN portlari su an <code>br0</code> koprusunde. Ancak STA baglantisi
        gercekten kurulmadan ve 4-address/WDS veya NAT destegi dogrulanmadan,
        Ethernet internet paylasimi etkinlestirilmez. Bu kisim, baglanti testinden sonra acilacak.</p>
      </div>
      <div style="margin:12px 0;max-width:890px">
        <b>Durum:</b> <span id="ycState">Hazir</span>
        <div style="margin-top:7px"><b>Debug Console</b> &nbsp;
          <input class="Button" type="button" id="ycClearLog" value="Temizle" /></div>
        <pre id="ycDebug" style="white-space:pre-wrap;word-break:break-word;min-height:150px;max-height:360px;overflow:auto;background:#171717;color:#ddd;padding:10px;font:12px/1.45 monospace"></pre>
      </div>
      <p style="text-align:center;border-top:1px solid #ddd;padding:10px;font-size:12px">
        <a href="https://github.com/yulcaribe" target="_blank" rel="noopener noreferrer">github.com/yulcaribe</a>
        &nbsp; | &nbsp; &copy; YulCaribe
      </p>
    </div></div>
  </div>
</div>
<script type="text/javascript">
(function(){
  var $root = $('#YCRepeaterRoot');
  var busy = false;
  var seen = {};
  var networkCount = 0;
  function ui(id){return $root.find('#'+id);}
  function stamp(){try{return new Date().toISOString();}catch(e){return '';}}
  function log(msg){
    var box=ui('ycDebug');
    box.text(box.text()+'['+stamp()+'] '+msg+'\n');
    if(box[0])box[0].scrollTop=box[0].scrollHeight;
  }
  function xmlText(xml,tag){try{return $(xml).find(tag).first().text();}catch(e){return '';}}
  function endpoint(){return 'getpage.lua?pid=1005&nextpage=Internet_STA_Switch_lua.lua';}
  function token(){try{if(typeof _sessionTmpToken!=='undefined')return _sessionTmpToken;}catch(e){}return '';}
  function showStatus(xml){
    ui('ycRole').text(xmlText(xml,'NetSphereMode')||'-');
    ui('ycEnabled').text(xmlText(xml,'NetSphereEnable')||'-');
    var n2=$(xml).find('AP2G ESSID').first().text();
    var n5=$(xml).find('AP5G ESSID').first().text();
    ui('ycCurrentAP2').text(n2||'-');ui('ycCurrentAP5').text(n5||'-');
    if(n2&&!ui('ycAP2SSID').val())ui('ycAP2SSID').val(n2);
    if(n5&&!ui('ycAP5SSID').val())ui('ycAP5SSID').val(n5);
  }
  function updateSurvey(raw, band){
    ui('ycScanRaw').text(raw||'(Bos sonuc)');
    var lines=(raw||'').split(/\r?\n/), added=0;
    for(var i=0;i<lines.length;i++){
      var m=lines[i].match(/^\s*(\d{1,3})\s+(.+?)\s+([0-9a-f]{2}(?::[0-9a-f]{2}){5})\s+(.+)$/i);
      if(!m)continue;
      var ssid=m[2].trim(), bssid=m[3].toLowerCase();
      if(!ssid || ssid.length>32)continue;
      var key=band+'/'+bssid;
      if(seen[key])continue;
      seen[key]=1;networkCount++;added++;
      var opt=document.createElement('option');
      opt.value=ssid;opt.setAttribute('data-band',band);
      opt.textContent=(band==='2g'?'2.4 GHz':'5 GHz')+' | '+ssid+' | '+m[4].trim();
      ui('ycScanResults').append(opt);
    }
    ui('ycScanCount').text('Bulunan: '+networkCount+' (son tarama +'+added+')');
    if(added===0)log('Tarama tamamlandi, tablo formatindan SSID ayrilamadi; ham sonucu yukaridan kontrol edin.');
  }
  function request(action,fields){
    if(busy)return;
    busy=true;ui('ycState').text(action+' calisiyor...');
    var isGet=!action || action==='Status';
    var payload={IF_ACTION:action,_sessionTOKEN:token()};
    if(fields)for(var key in fields)if(Object.prototype.hasOwnProperty.call(fields,key))payload[key]=fields[key];
    log('REQUEST '+(action||'Status')+' (sifre ve oturum anahtari loglanmaz)');
    $.ajax({url:endpoint(),type:isGet?'GET':'POST',cache:false,dataType:'xml',timeout:35000,
      data:isGet?{}:payload
    }).done(function(xml,ts,xhr){
      showStatus(xml);
      var error=xmlText(xml,'IF_ERRORID'), errstr=xmlText(xml,'IF_ERRORSTR');
      var out=xmlText(xml,'Output');
      ui('ycState').text((error===''||error==='0')?'OK: '+action:'HATA '+error+': '+errstr);
      if(out)log('OUTPUT:\n'+out);
      if(error!==''&&error!=='0')log('Backend hata '+error+' '+errstr);
      if(action==='Scan2g'||action==='Scan5g')updateSurvey(out,action==='Scan2g'?'2g':'5g');
      if(action==='Mode7'||action==='Mode1'||action==='ModeLog'){
        var modeLog=xmlText(xml,'ModeLog');if(modeLog)log('MODE LOG:\n'+modeLog);
      }
    }).fail(function(xhr,ts,err){
      ui('ycState').text('HTTP/AG HATASI');
      log('HTTP '+xhr.status+' '+ts+' '+err+' '+(xhr.responseText||'').slice(0,1500));
    }).always(function(){busy=false;});
  }
  function valid(ssid,key){
    if(!ssid || new TextEncoder().encode(ssid).length>32){alert('SSID 1-32 bayt olmali.');return false;}
    if(!key || new TextEncoder().encode(key).length<8 || new TextEncoder().encode(key).length>63){alert('WPA2 parola 8-63 bayt olmali.');return false;}
    if(/[\x00-\x1f\x7f]/.test(ssid+key)){alert('Kontrol karakterleri kullanilamaz.');return false;}
    return true;
  }
  function publish(band){
    var id=band==='2g'?'2':'5', ssid=ui('ycAP'+id+'SSID').val(), key=ui('ycAP'+id+'Key').val();
    if(!valid(ssid,key))return;
    if(!confirm('Bu bandin mevcut Wi-Fi yayinini degistirebilir, baglantinizi kesebilir. Ethernet baglantiniz var mi?'))return;
    request(band==='2g'?'Publish2g':'Publish5g',{SSID:ssid,Key:key});
  }
  function connect(){
    var band=ui('ycStaBand').val(), ssid=ui('ycStaSSID').val(), key=ui('ycStaKey').val();
    if(!valid(ssid,key))return;
    if(!confirm('Deneysel ApCli STA baglantisi denenecek. Bu build surucusu desteklemeyebilir. Devam?'))return;
    request(band==='2g'?'Connect2g':'Connect5g',{SSID:ssid,Key:key});
  }
  ui('ycScanResults').change(function(){
    var opt=this.options[this.selectedIndex];
    if(opt&&opt.value){ui('ycStaSSID').val(opt.value);ui('ycStaBand').val(opt.getAttribute('data-band')||'2g');}
  });
  ui('ycClearLog').click(function(){ui('ycDebug').text('');});
  ui('ycRefresh').click(function(){request('Status');});
  ui('ycFullStatus').click(function(){request('FullStatus');});
  ui('ycScan2').click(function(){request('Scan2g');});
  ui('ycScan5').click(function(){request('Scan5g');});
  ui('ycConnect').click(connect);
  ui('ycPublish2').click(function(){publish('2g');});
  ui('ycPublish5').click(function(){publish('5g');});
  ui('ycAP2On').click(function(){request('APOn2g');});
  ui('ycAP5On').click(function(){request('APOn5g');});
  ui('ycAP2Off').click(function(){if(confirm('2.4 GHz arayuzu 90 saniye kapatilacak. Devam?'))request('APOff2g');});
  ui('ycAP5Off').click(function(){if(confirm('5 GHz arayuzu 90 saniye kapatilacak. Devam?'))request('APOff5g');});
  ui('ycMode7').click(function(){if(confirm('Mod 7 gercek ag topolojisini degistirir. 180 saniye icinde baglanti kopabilir. Ethernet ve kurtarma yolu varsa devam edin.'))request('Mode7');});
  ui('ycMode1').click(function(){if(confirm('ZTE work mode 1 geri yuklenecek. Devam?'))request('Mode1');});
  ui('ycConfirmMode').click(function(){if(confirm('180 saniyelik otomatik geri donusu IPTAL etmek istiyor musunuz?'))request('ConfirmMode');});
  log('YulCaribe H298A repeater v0.3 loaded');
  request('Status');
})();
</script>
]=]
cgilua.put(html)
