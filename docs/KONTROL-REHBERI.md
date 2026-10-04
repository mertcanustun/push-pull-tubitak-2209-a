# Senaryo 2: teknik olmayan ekip için kontrol ve ayar rehberi

> **Kimin için:** Godot'u ilk kez açan, kod yazmayan ekip arkadaşları (İlayda, Berk, hocalar).
> **Durum:** Ayar ve düğüm adları, varsayılanlar ve ölçülen değerler 2026-10-04'te uygulamayla
> eşleştirildi (dal `ozellik/ayar-ve-godot-fizik`). Sayılar varsayılan fizik motoru
> **Godot Melez** ile ölçüldü.

---

## 0. Kurulum (bir kere)

1. **Godot 4.5.x** indir: godotengine.org → Download → macOS/Windows. Kurulum yok, aç ve çalıştır.
2. Projenin güncel hâlini al. GitHub Desktop kullanıyorsan *Fetch → Pull*; Defne/Mert sana zip de verebilir.
3. Godot'u aç → **Import** → proje klasöründeki `project.godot`'u seç → **Import & Edit**.
4. Sağ üstteki **▶ (veya F5)** ile çalıştır. Kapatmak için oyun penceresini kapat veya **F8**.

## 1. Godot ekranı: 5 dakikalık tur

| Panel | Nerede | Ne işe yarar |
|---|---|---|
| **Scene** (Sahne) | sol üst | Sahnedeki nesnelerin ağacı (salon, toplar, kamera…). Tıklayınca seçilir. |
| **FileSystem** | sol alt | Projedeki dosyalar. Ayar dosyası buradan açılır. |
| **Inspector** | sağ | Seçili nesnenin/dosyanın ayarları: sayı kutuları, renk seçiciler, açılır listeler. Bir alanın üstünde fareyi bekletirsen **Türkçe açıklaması** çıkar. |
| **Output** | alt | Mesajlar ve hatalar. **Kırmızı satır = hata**; ekran görüntüsünü al. (macOS'ta açılışta çıkan 3 kırmızı *MuJoCo* satırı bilinen bir durumdur, bkz. §6.) |
| **▶ / ■** | sağ üst | Çalıştır / durdur. |

**Altın kural:** Bir alanı değiştirdiğinde yanında küçük bir **↺** oku çıkar. Ona basınca değer
varsayılana döner. Bir şey bozulursa önce ↺.

## 2. Ayar değiştirmenin iki yolu

### A) Canlı deneme: oyun çalışırken, kaydedilmez
1. **▶** ile çalıştır.
2. Godot editörüne dön → **Scene** panelinin üstünde **Remote** sekmesine tıkla (çalışan oyunun canlı ağacı).
3. **Main** düğümünü seç → Inspector'da **Ayarlar → Cfg** alanını aç.
4. Bir değeri değiştir → oyuna dön:
   - **Top / Hava / Temas** grupları: oyunda **R** (ya da *Sıfırla*) bas, sonraki düşüşte işler.
   - **Fizik Motoru**: sahne kendiliğinden sıfırlanır.
   - **Hava Modeli, Seçenekler, Görsel, (b) gösterimi**: hemen işler.
5. ⚠️ Oyunu kapatınca bu değişiklikler **kaybolur**. Beğendiğin değeri not al.

### B) Kalıcı değişiklik: kaydedilir
1. **FileSystem** → `config/sim2_config.tres` dosyasına **tek** tıkla.
2. Inspector'da değeri değiştir → **Ctrl+S** (Mac'te **Cmd+S**).
3. ▶ ile dene.
4. ⚠️ Kalıcı değişiklikleri repoya göndermeden önce **Defne'ye haber ver** (kural: onaysız push yok).

## 3. Ayar dosyası: `config/sim2_config.tres` (tüm ayarlar)

Gruplar Inspector'da açılır-kapanır başlıklar olarak görünür. **Inspector'da** sütunu, alanın
Inspector'daki adıdır (Godot alan adını İngilizce harflerle ve baş harfleri büyük yazar; dar
panelde ad kısaltılmış görünebilir).

### Fizik Motoru
| Inspector'da | Varsayılan | Ne yapar | Değiştirince neye bak |
|---|---|---|---|
| Backend | **Godot Melez** | Hareketi hangi motor hesaplasın: **Mujoco / Yedek Cozucu / Godot Melez** | Sahne sıfırlanır. Üst durum satırı hangi motorun çalıştığını yazar. Sol topun ilk sekmesi Yedek Çözücü'de 1.56 m, Godot Melez'de 1.52–1.60 m (kare zamanlamasına göre küçük oynama). **Mujoco** yalnızca masaüstünde ve derlenmişse çalışır, yoksa Yedek Çözücü'ye düşer; web'de yoktur. |
| Godot Tik Sayisi | 120 Hz | Yalnızca Godot Melez: saniyedeki fizik adımı | Artırınca Yedek Çözücü sonuçlarına yaklaşır, işlemci daha çok çalışır. Motor bir sonraki seçilişinde/başlatmada işler. |

### Top
| Inspector'da | Varsayılan | Ne yapar | Neye bak |
|---|---|---|---|
| Mass | 0.624 kg | Topun kütlesi (NBA topu) | Ağırlık oku (G) büyür/küçülür; zemin kuvveti de orantılı değişir. 2 kg'da temas 7.5 → 13.8 ms, tepe N 1665 → 3011 N (ölçüldü). |
| Radius | 0.119 m | Topun boyutu | Top görünür boyut değiştirir. |
| Restitution | 0.76 | Sekme katsayısı (0 = hiç, 1 = kayıpsız) | Sol top: 0.5'te ~0.77 m, 0.76'da ~1.5 m, 0.9'da ~2.06 m'ye seker (3 m'den bırakılınca, ölçüldü). (a) şıkkında sağ top solla **birebir** aynı seker. |

### Hava
| Inspector'da | Varsayılan | Ne yapar | Neye bak |
|---|---|---|---|
| Hava Modeli | Gercekci Kare | **Gercekci Kare / Godot Sonum Dogrusal / Kapali** | (b)'de ekrandan çıkınca yazan tepe noktası: gerçekçi ≈ **196–200 m**, doğrusal ≈ **2400 m**, kapalı ≈ **87 km**. Sol topun ilk sekmesi: 1.52 / 1.12 / 1.65 m (ölçüldü). |
| Hava Yogunlugu | 1.225 kg/m³ | Deniz seviyesi havası | Artırınca top yavaşlar, mavi Fs oku büyür. |
| Drag CD | 0.47 | Sürüklenme katsayısı, küre için tipik değer | Aynı etki. |
| Dogrusal Sonum | 0.449 | Yalnızca "Godot Sonum Dogrusal" modelinde kullanılır | Diğer modellerde etkisi yok. |

### Temas
| Inspector'da | Varsayılan | Ne yapar | Neye bak |
|---|---|---|---|
| Temas Suresi | 0.008 sn (8 ms) | Seçim kuvvetinin (a/b/c) hesaplandığı varsayılan temas süresi (J = F·T'deki T) | Kısaltınca geri bildirim yazısındaki ve (b)/(c)'deki N **büyür** (aynı itiş daha kısa sürede). Bu süre bir **varsayım** olduğu için sayılar "≈" ile verilir. Sol topun kendi teması bundan bağımsızdır. |
| Sertlik | 100000 N/m | Topun "yay" sertliği | Azaltınca temas uzar, top zemine daha çok gömülür; artırınca temas kısalır. Çok düşük değerler gerçekçi değildir. |

### Seçenekler
| Inspector'da | Varsayılan | Ne yapar | Neye bak |
|---|---|---|---|
| B Carpani | 100 | (b) şıkkında zeminin topa uyguladığı kuvvetin kaç katı | Top **10'da da** ekrandan çıkar (~84 m tepe), 2'de de çıkar; ekranda kalması için 1 olmalı (ölçüldü). Senaryo planında **100** yazıyor; değiştirmeden önce İlayda/Berk ile karar verin. ⚠️ Seçenek düğmesindeki "100·F" yazısı bu ayarla değişmez (sabit metin), geri bildirim yazısı değişir. |

### Görsel
| Inspector'da | Varsayılan | Ne yapar | Neye bak |
|---|---|---|---|
| OK Olcegi | 0.36 | Okların genel boyu (ölçek **logaritmik**: küçük ve dev kuvvetler aynı ekrana sığsın diye) | Oklar ekrandan taşıyorsa küçült. |
| Agir Cekim Carpani | 0.05 | Top zemine yaklaşırken zaman ne kadar yavaşlasın (0.05 = 20× yavaş) | Temas anında okların büyüyüp küçülmesi rahat izlenebilmeli. |
| Ekrandan Cikis Yuksekligi | 9 m | (b)'de top bu yüksekliği geçince "ekrandan çıktı" sayılır | Tepe noktası mesajının ne zaman çıktığı. |

### (b) gösterimi
| Inspector'da | Varsayılan | Ne yapar | Neye bak |
|---|---|---|---|
| B Gosterim | Ikisi | **Kamera Takip / Firlatma Agir Cekim / Ikisi / Hicbiri** | Dördünü sırayla dene: hangisinde öğrenci fırlamayı en iyi görüyor? Hicbiri = eski davranış (top 9 m'de durur, yalnız yazı). |
| Firlatma Agir Cekim Carpani | 0.01 | Fırlatma anındaki yavaşlama | 0.01'de ilk 9 m ≈ 1.1 saniyede izlenir (ölçüldü). |
| Firlatma Agir Cekim Suresi | 3.0 sn | Fırlatma ağır çekiminin üst sınırı (gerçek saniye) | Normalde top ekrandan çıkınca zaten biter; yalnızca güvenlik sınırı. |
| Kamera Takip Suresi | 8.0 sn | Kamera takibinin üst sınırı (gerçek saniye) | Tepeye ~3.6 sn'de (İkisi modunda ~4.5 sn) varılıyor; süre dolarsa takip tepeyi beklemeden biter. |
| Kamera Takip Max Yukseklik | 250 m | Kamera en fazla buraya kadar çıkar | Tepe ~200 m; daha yükseğe giderse top kadrajdan çıkar ama yazı saymaya devam eder. |
| Kamera Tepe Bekleme | 1.0 sn | Kamera tepede bu kadar bekler | "Tepe noktası: … m" yazısı okunabilmeli. |
| Kamera Donus Suresi | 1.5 sn | Kameranın ana konumuna dönüş süresi | Kamera sonunda **tam olarak** eski konumuna dönmeli (sıçrama olmamalı). |
| Yukseklik Isaret Araligi | 5 m | Takipteki yükseklik cetvelinde etiket aralığı (çentikler her 1 m) | Kadrajda her an en az bir etiket görünmeli. |

⚠️ **Godot Melez'de iki farklı tepe sayısı:** üst durum satırı formülle hesaplanan değeri
(~196–200 m) yazar; kamera takibindeki sarı yazı ise topun **gerçekten uçtuğu** tepeyi
(~185 m) gösterir. Fark, takip sırasında büyük fizik adımlarından geliyor
(bkz. `docs/motor-karsilastirma.md`). Yedek Çözücü'de ikisi 199–200 m.

## 4. Sahnedeki nesneler: tıklayıp Inspector'dan değiştirilebilir

**Scene** panelinde (Remote değil, normal **Local** sekmesi) `Main`'in altında:

| Düğüm | İçinde | Değiştirilebilecekler |
|---|---|---|
| `Ortam/Parke` | `Tahtalar` (tek bir çoklu-örnek nesne) | (toplu renk; tek tek değil) |
| `Ortam/Bolgeler` | `Bolge1` (sol), `Bolge2` (sağ) yarı saydam bölgeler, **ikisi de turuncu** (Defne'nin seçimi) | Malzeme → Albedo rengi ve saydamlık |
| `Ortam/SahaCizgileri` | `DipCizgi`, `YanCizgiSol/Sag`, `BoyaliAlan`, serbest atış ve üçlük çizgileri | renk, `BoyaliAlan` rengi |
| `Ortam/Pota` | `Taban`, `Direk`, `Kol`, `Panya`, `Cember`, `File` | renkler |
| `Ortam/Tribun` | `Basamak0…5` + `SeyirciGovde` / `SeyirciKafa` | basamak renkleri |
| `Ortam/Duvarlar` | `ArkaDuvar`, `YanDuvarSol/Sag`, `Serit…`, `Flama…` | renkler |
| `Ortam/Skorbord` | `Kasa`, `Ekran`, `Baslik`, `AltBaslik` | **Text** alanı (ör. "ETKİ – TEPKİ"), renk, boyut |
| `Ortam/TavanIsiklari` | 3 ışık (`Tavan_-4_-3`, `Tavan_4_-3`, `Tavan_0_-8`) | **Energy** (parlaklık), renk |
| `WorldEnvironment` | arka plan, ortam ışığı, sis, parlama | Environment → Background color, Ambient light energy, Fog density, Glow |
| `Sun` | ana ışık | Energy, renk (gölge web'deki bir hata yüzünden bilerek kapalı) |
| `Camera3D` | ana kamera | ⚠️ Dokunma: (b) kamera takibi buraya geri dönüyor |
| `TopSol`, `TopSag` | toplar (`ball.tscn`, birer `RigidBody3D`) | Inspector'ın en üstünde **"Fizik → sim2_config.tres"** başlığı var. Değiştirilebilecekler: alt düğümlerde doku (`Kure`), toz (`Toz`), ses (`Ses`), ok renkleri (`Oklar/…`); topun kendisinde **Çarpma sesi** grubu. ⚠️ **RigidBody3D bölümündeki Mass / Physics Material / Gravity Scale / Linear-Angular Damp alanlarına ve "Boyut → Radius"a dokunma**: MuJoCo ve Yedek Çözücü modlarında top Godot'ta "dondurulmuş kukla"dır ve bu alanlar hiçbir şeyi değiştirmez; Godot Melez'de ise her sıfırlamada `sim2_config.tres`'ten yeniden yazılır. Fizik ayarı **yalnızca** ayar dosyasından yapılır. |

⚠️ **Önemli: salonu nereden değiştirirsin:** `Ortam` bir üretici betikle (`tools/build_environment.gd`)
oluşturuluyor ve betik tekrar çalıştığında `Ortam`'ı baştan kurar. `Ortam`'ın alt düğümlerinde
doğrudan yaptığın değişiklikler yeniden üretimde **silinir**. Kalıcı değişiklik için Defne'ye haber ver.

## 5. Kontrol listesi: her yeni sürümde bak

Her maddeyi ✅/❌ işaretle; ❌ olanların ekran görüntüsünü al (bkz. §6).
Son otomatik kontrolün sonucu §8'de.

### Açılış ve düşüş
- [ ] Proje hatasız açılıyor; **Output**'ta (MuJoCo satırları dışında) kırmızı satır yok.
- [ ] Üst durum satırı hangi fizik motorunun çalıştığını yazıyor ve doğru.
- [ ] **SPACE / Başlat**: iki top aynı anda, aynı hızda düşüyor.
- [ ] Toplar zemine yaklaşırken zaman yavaşlıyor.
- [ ] Sağ top zemine değdiği anda simülasyon duruyor ve **üç seçenek** çıkıyor.
- [ ] O anda iki top da aynı yükseklikte (zemine değiyor).

### Seçenek (a): doğru cevap
- [ ] Sağ top, sol topla **aynı yüksekliğe** sekiyor (birebir aynı hareket).
- [ ] Temas sırasında solda yeşil **N**, sağda aynı büyüklükte mor **F** oku yukarı bakıyor, büyüyüp küçülüyor.
- [ ] Geri bildirim metni doğru ve anlaşılır.

### Seçenek (b): 100F
- [ ] Fırlatma gözden kaçmıyor (ağır çekim ve/veya kamera takibi).
- [ ] Kamera sonunda eski konumuna sıçramadan dönüyor.
- [ ] Tepe noktası mesajı gerçekçi hava modelinde **≈ 200 m** diyor (60 000 m gibi bir sayı **hata**dır).
- [ ] Geri bildirim metni doğru.

### Seçenek (c): kuvvetler götürür
- [ ] Sağ top zeminde **duruyor**.
- [ ] Aynı topun üzerinde **eşit ve zıt iki ok** görünüyor (yeşil N yukarı, mor F aşağı; yanılgının görselleştirmesi).
- [ ] Geri bildirim metni "çift **farklı** cisimlere etki eder" fikrini açıkça veriyor.

### Oklar ve sayılar
| Renk | Etiket | Anlamı | Onay kutusu (sol alt panel) |
|---|---|---|---|
| kırmızı | G | ağırlık (m·g) | Yerçekimi |
| mavi | Fs | hava sürtünmesi | Hava sürtünmesi |
| yeşil | N | zeminin topa tepkisi | Zemin tepkisi |
| mor | F | uygulanan kuvvet (seçim / ok aracı) | Uygulanan kuvvet |
| sarı | Fnet | ölçülen net kuvvet (m·a) | Net kuvvet |
| turuncu | Fnet-G | net kuvvetten yerçekimi çıkarılmış (varsayılan kapalı) | Fnet − G |
- [ ] Ok onay kutuları ilgili oku açıp kapatıyor.
- [ ] Sayılar okunuyor; büyük kuvvetlerde "≈" var.
- [ ] Sağ ve sol panelde aynı top için **aynı sayı** yazıyor.

### Görsel
- [ ] Saha çizgileri titremiyor (kamera kıpırdamadan çizgiler yanıp sönmüyor).
- [ ] Skorbord panyanın arkasında kalmıyor; yazılar okunuyor (Türkçe karakterler doğru).
- [ ] Oklar ve toplar arka planla karışmıyor.
- [ ] Toz parçacıkları ve çarpma sesi temas anında çalışıyor.

### Kontroller
- [ ] **R / Sıfırla** baştan başlatıyor. **Simülasyon hızı** kaydırıcısı zamanı değiştiriyor.
- [ ] **Ok aracı (sürükle-bırak):** kutuyu işaretle, topa tıklayıp sürükle → kuvvet uygulanıyor. (Şu an bırakınca kuvvet **kalıcı** kalıyor ve top hızlanmaya devam ediyor. Açık soru: böyle mi kalmalı? Mert'e sorulacak.)

### Fizik motoru karşılaştırması
- [ ] Ayardan motoru değiştir (Yedek Cozucu ↔ Godot Melez) → sol topun sekme yüksekliği birkaç % içinde aynı.
- [ ] `docs/motor-karsilastirma.md` tablosundaki değerlerle ekrandaki uyumlu.

### Web sürümü (Vercel linki)
- [ ] Tarayıcıda açılıyor (Chrome ve Safari ayrı ayrı dene).
- [ ] Yukarıdaki a/b/c kontrolleri web'de de geçiyor.
- [ ] Durum satırı MuJoCo **değil** (web'de MuJoCo yok, bu normal).
- [ ] Akıcı (takılma yok); ışık masaüstüne göre biraz farklı olabilir.

### Pedagojik bakış (İlayda/Berk)
- [ ] Metinler öğrenci diliyle, kısa ve doğru.
- [ ] (c)'nin **yanlış** bir dünya olduğu öğrenciye net.
- [ ] "Fnet − G" oku öğrenciye kafa karıştırıyorsa varsayılan olarak kapalı kalsın mı? (karar; şu an kapalı)
- [ ] Sayılar (≈1000 N gibi) öğrenci için anlamlı mı, yoksa "ağırlığın kaç katı" mı yazılmalı? (karar)

## 6. Bir şey ters giderse

1. Önce **↺** ile varsayılana dön; düzelmezse oyunu kapatıp yeniden aç.
2. Kalıcı bir değişikliği geri almak için: GitHub Desktop → değişen dosyaya sağ tık → **Discard changes**.
3. **Bilinen durum:** macOS'ta açılışta Output'ta *"Can't open dynamic library … libmujoco_godot"*
   ile başlayan 3 kırmızı satır çıkar. MuJoCo eklentisi bu makinede derlenmediği içindir; simülasyon
   etkilenmez (Godot Melez / Yedek Çözücü çalışır).
4. **Hata bildirimi** (Defne'ye) şu dört satırla:
   - Ne yaptım: (ör. "Fizik motorunu Godot yaptım, (b)'yi seçtim")
   - Ne bekliyordum:
   - Ne oldu:
   - Ekran görüntüsü + **Output** panelindeki kırmızı satır(lar)

## 7. Henüz olmayanlar (sonraki paketler)
- **Ekrandaki metinler** (seçenekler, geri bildirim) şu an kodun içinde, yani teknik olmayan ekip
  değiştiremiyor. Senaryo 1'deki gibi bir metin dosyasına (CSV) taşınması önerildi.
- **Telemetri** (katılımcı kodu + veri toplama): Senaryo 2'de yok.
- **Açılış sahnesi** (top sektiren oyuncu + kamera yolculuğu).

## 8. Son kontrol sonucu (Claude Code, 2026-10-04, masaüstü macOS, Godot Melez)

Otomatik testler + ekran görüntüleriyle yapıldı. Pedagojik maddeler ekibin kararıdır.

| Madde | Sonuç | Not |
|---|---|---|
| Hatasız açılış | ⚠️ | Yalnız bilinen 3 MuJoCo satırı (§6). Godot Melez'de birkaç Sıfırla sonrası çıkan `p_elem->_root` motor hatası bu sürümde giderildi. |
| Durum satırı motoru yazıyor | ✅ | "Fizik motoru: Godot Melez (Godot uçuş + bizim temas/hava)" |
| İki top aynı anda düşüyor | ✅ | |
| Yaklaşırken ağır çekim | ✅ | Engine.time_scale 1.0 → 0.05 |
| Sağ top değince durup 3 seçenek | ✅ | |
| O anda iki top aynı yükseklikte | ✅ | ikisi 0.1226 m (aynı) |
| (a) aynı yüksekliğe sekiyor | ✅ | sol/sağ 1.525/1.525, 0.850/0.850, 0.482/0.482 m; fark 0.0 mm |
| (a) N/F okları | ✅ | solda N 1607 N, sağda F 1607 N, Fnet ikisinde 1520 N |
| (a) geri bildirim | ⚠️ | Metin doğru ama "N ≈ 998 N" diyor; oklar temas sırasında ~1600 N gösteriyor (998, 8 ms varsayımından gelen ortalama). Ekip kararı: metin "ortalama" desin mi? |
| (b) fırlatma görünüyor | ✅ | ağır çekim 1.1 sn, sonra kamera takibi |
| (b) kamera birebir dönüyor | ✅ | 4 mod × 2 motor ölçüldü, hepsi "birebir" |
| (b) ≈ 200 m | ⚠️ | Durum satırı 196–200 m ✅; Godot Melez'de takip yazısı 185–186 m (gerçek uçuş). İki farklı sayı aynı anda ekranda. |
| (b) geri bildirim | ✅ | |
| (c) top duruyor | ✅ | hız 0, y = 0.119 |
| (c) eşit-zıt iki ok | ✅ | N 998 yukarı, F 998 aşağı; mor F okunun etiketi geri bildirim kutusunun arkasında kalıyor (küçük görsel sorun) |
| (c) geri bildirim | ✅ | |
| Ok onay kutuları | ✅ | G kapat → G oku gizlendi, aç → göründü |
| "≈" ve okunurluk | ✅ | kamera takibinde "Fs" etiketi "G" etiketiyle kısmen üst üste biniyor |
| Sol/sağ panel = oklar | ✅ | (a)'da panel ve oklar aynı (1607 / 1520) |
| Saha çizgileri titremiyor | ✅ | durağan karelerde titreme yok (hareketli kamera ayrıca denenmeli) |
| Skorbord okunuyor | ✅ | "ETKİ – TEPKİ / Newton'un 3. yasası", panyanın üstünde |
| Toz + ses | ✅ | iki topta da temasta toz yayıldı, ses çaldı |
| R / Sıfırla, hız kaydırıcısı | ✅ | R → başa döndü; hız 0.5 → zaman yarıya indi |
| Ok aracı | ✅ | sürükleyince kuvvet uygulandı; kuvvet bırakınca kalıcı (açık soru) |
| Motor karşılaştırması | ✅ | ilk sekme Yedek 1.561 m, Godot Melez 1.52–1.60 m |
| Web (yerel dışa aktarım, Chrome) | ✅ | Godot Melez'de a/b/c geçti, durum satırı MuJoCo değil |
| Web: Vercel linki ve Safari | ❌ denenmedi | yalnız yerel dışa aktarım headless Chrome'da denendi |
| Pedagojik maddeler | — | İlayda/Berk |
| Durum satırı seçimden sonra | ⚠️ | (a)/(c) seçildikten sonra da "zemin topa hangi kuvveti uygular?" yazmaya devam ediyor |
