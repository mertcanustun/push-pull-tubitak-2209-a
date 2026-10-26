# Uzak kayıt (Vercel)

Web sürümü her seçimi ve her cevabı Vercel'deki `/api/log` uç noktasına
gönderir. Kayıtlar Upstash Redis'te tutulur, öğretmen CSV olarak indirir.
Yerel `user://cevaplar.csv` kaydı da yazılmaya devam eder.

## Parçalar

| Yer | Dosya | Görev |
|---|---|---|
| Oyun | `scripts/kayit.gd` (autoload `Kayit`) | Olayları kuyruğa alır, sırayla POST eder, hata olursa 5 s sonra tekrar dener |
| Oyun | `scripts/main.gd` | `secim`, `cevap`, `cevap_gecildi` olaylarını çağırır |
| Vercel deposu | `api/log.js` | `POST /api/log`: olayı doğrular ve Redis listesine ekler |
| Vercel deposu | `api/export.js` | `GET /api/export?anahtar=…`: tüm kayıtlar CSV (veya `&bicim=json`) |
| Vercel deposu | `api/_redis.js` | Upstash REST istemcisi (bağımlılık yok) |

## Kurulum (bir kez)

1. Vercel → proje → **Storage** → **Upstash for Redis** → Create → projeye bağla.
   `KV_REST_API_URL` ve `KV_REST_API_TOKEN` kendiliğinden eklenir.
2. Vercel → proje → **Settings → Environment Variables** → `LOG_ADMIN_KEY` =
   uzun, tahmin edilemez bir parola.
3. `push-pull-tubitak-2209-a-on-vercel` deposunda `api/` klasörünü commit + push et.
   Godot'tan dışa aktarma yalnızca `index.*` dosyalarını yazar, `api/`'ye dokunmaz.
4. Kayıtları indir: `https://<site>.vercel.app/api/export?anahtar=<LOG_ADMIN_KEY>`

## Sütunlar

`sunucu_zamani, istemci_zamani, oturum, olay, mod, secenek, secenek_metni, soru, cevap`

- `oturum`: sayfa her açıldığında rastgele bir kimlik. Aynı öğrencinin olaylarını gruplar, isim içermez.
- `olay`: `oturum_basladi`, `secim`, `cevap`, `cevap_gecildi`
- `mod`: `referansli` / `referanssiz`

## Notlar

- Masaüstü sürümü varsayılan olarak göndermez. Göndermesi için `kayit.gd` → `MASAUSTU_ADRES`.
- `index.html` dosyasını `file://` ile açınca da gönderim olmaz.
- `/api/log` herkese açıktır (oyun girişsiz çalışıyor). Alanlar 2000 karakterde kesilir, bilinmeyen olaylar reddedilir.
- Kayıtları silmek: Upstash konsolunda `DEL kayitlar`.
