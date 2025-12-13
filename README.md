# Rendivo Mobile

Flutter tabanlı Rendivo, salon ve spa işletmeleri ile müşterilerini buluşturan uçtan uca randevu yönetim çözümüdür. Depoda hem mobil istemci (Flutter) hem de REST API (Express + MySQL) yer alır.

## Proje Amacı

- **Müşteriler:** İşletmeleri keşfetme, hizmet seçme, randevu oluşturma ve geçmişi görüntüleme.
- **İşletme sahipleri:** Kayıt akışı, hizmet & personel özetleri ve işletme panelleri üzerinden operasyon takibi.
- **Personel:** Yaklaşan randevularını takip etme ve müşteri bilgilerine hızlı erişim.
- **Servis katmanı:** HTTP tabanlı kimlik doğrulama, randevu oluşturma/iptal etme ve oturum yönetimi.

## Klasör Yapısı

- `lib/` – Flutter uygulaması (ekranlar, modeller, servis katmanı, tema).
- `assets/` – Görseller ve ilüstrasyonlar.
- `backend/` – Express.js API, MySQL bağlantıları ve JWT kimlik doğrulaması.

## Kullanılan Servisler & Teknolojiler

- **Flutter** (Material, `http`, özel tema) – mobil istemci.
- **Express.js** + **MySQL** – REST API, JWT tabanlı auth, randevu CRUD işlemleri.
- **bcryptjs** – parola hashleme.
- **jsonwebtoken** – erişim token’ları.
- **mysql2/promise** – veritabanı bağlantıları.
- **dotenv** – sunucu ortam değişkenleri.

## Gereksinimler

- Flutter SDK 3.2.6+
- Dart 3
- Node.js 18+ ve npm
- MySQL 8.x

## Kurulum Adımları

### 1. Depoyu alın

```bash
git clone <repo-url>
cd RendivoMobile
```

### 2. Flutter bağımlılıklarını yükleyin

```bash
flutter clean
flutter pub get
```

### 3. Backend ortamını hazırlayın

```bash
cd backend
cp .env.example .env   # dosya yoksa README’deki şablondan yeni .env oluşturun
npm install
```

`.env` içeriği örneği:

```env
PORT=5000
JWT_SECRET=super-secret
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=rendivo
DB_PASSWORD=yourpassword
DB_NAME=rendivo
DB_SSL=false
FRONTEND_URL=http://localhost:3000
```

### 4. Veritabanını oluşturun

- MySQL’de `DB_NAME` karşılığı veritabanını oluşturun.
- `users`, `businesses`, `services`, `appointments`, `staff_members` vb. tabloları proje şemasına göre açın (migration dosyaları henüz repo’ya eklenmediği için manuel olarak oluşturmanız gerekir).

## Uygulamayı Çalıştırma

### Backend API

```bash
cd backend
npm run dev           # nodemon ile
# veya
npm start             # node server.js
```

Sunucu varsayılan olarak `http://localhost:5000/api` altında hizmet verir.

### Flutter mobil istemci

Varsayılan taban URL Android emülatörü için `http://10.0.2.2:5000/api`, diğer platformlar için `http://localhost:5000/api` şeklindedir. Farklı bir endpoint kullanmak isterseniz build sırasında `API_BASE_URL` tanımlayabilirsiniz:

```bash
flutter run --dart-define=API_BASE_URL=https://your-server.com/api
flutter run --dart-define=API_BASE_URL='http://10.0.2.2:5000/api' mobil cihazlar için. 
```

Genel geliştirme komutları:

```bash
flutter pub get
flutter run
```

## Faydalı Komutlar

- Kod analizi: `flutter analyze`
- Widget testleri: `flutter test`
- Backend’i geliştirme modunda çalıştırma: `npm run dev`

## Yol Haritası (Özet)

- Şifre sıfırlama, sosyal giriş, staff onboarding ve business dashboard için yeni API’ler.
- Flutter tarafında kalıcı oturum saklama (`flutter_secure_storage`), dinamik takvim ve gerçek uygunluk kontrolü.
- Backend için migration dosyaları, otomatik testler ve CI adımları.

Sorularınız için Issues açabilir veya proje sahibine ulaşabilirsiniz.
