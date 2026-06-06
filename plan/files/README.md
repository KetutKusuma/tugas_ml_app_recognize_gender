# VoiceEmo — Flutter App

Aplikasi pengenalan emosi dari suara yang terhubung ke FastAPI backend.

---

## Struktur Folder

```
lib/
├── main.dart                    ← entry point
├── screens/
│   └── home_screen.dart         ← layar utama
├── services/
│   ├── audio_service.dart       ← rekam mic + pick file + trim FFmpeg
│   └── api_service.dart         ← kirim .wav ke /predict
└── widgets/
    └── emotion_card.dart        ← card hasil prediksi + bar probabilitas
```

---

## Package yang Digunakan

| Package | Fungsi | Alasan dipilih |
|---|---|---|
| `record` | Rekam mic → file | Stabil di iOS & Android, support WAV/AAC |
| `file_picker` | Pilih file audio | Cross-platform, support semua format audio |
| `ffmpeg_kit_flutter_min` | Trim + konversi ke WAV 16kHz | Satu-satunya solusi trim audio di Flutter |
| `dio` | HTTP multipart upload | Lebih handal dari `http` untuk upload file |
| `audioplayers` | Preview audio | Ringan, support local file |
| `permission_handler` | Request izin mic/storage | Standard permission management |
| `path_provider` | Folder temp | Untuk simpan file sementara |
| `path` | Manipulasi path | Utility string path |

---

## Setup & Instalasi

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Konfigurasi URL API

Edit `lib/services/api_service.dart`:

```dart
// Emulator Android
static const String _baseUrl = 'http://10.0.2.2:8000';

// Device fisik (iOS/Android) — ganti dengan IP LAN Mac Anda
static const String _baseUrl = 'http://192.168.x.x:8000';

// iOS Simulator
static const String _baseUrl = 'http://127.0.0.1:8000';
```

Cek IP LAN Mac Anda:
```bash
ifconfig | grep "inet " | grep -v 127
```

### 3. Jalankan server Python dulu

```bash
cd use_integ_mobile
uvicorn main:app --host 0.0.0.0 --port 8000
# --host 0.0.0.0 agar bisa diakses dari device fisik
```

### 4. Jalankan Flutter

```bash
flutter run
```

---

## Catatan Platform

### Android
- `usesCleartextTraffic="true"` di AndroidManifest sudah diset untuk testing localhost
- Production: hapus flag ini dan gunakan HTTPS

### iOS
- `NSAllowsArbitraryLoads` di Info.plist sudah diset untuk testing
- Production: ganti dengan `NSExceptionDomains` spesifik

### FFmpeg
- Package `ffmpeg_kit_flutter_min` ukurannya ~30MB
- Versi `min` dipilih agar tidak include codec GPL
- Fungsi: trim audio ke 3 detik + konversi ke WAV 16kHz mono

---

## Alur Aplikasi

```
User tekan "Rekam"
  └─► AudioService.recordFromMic()
       ├─► record package → file .m4a (3 detik)
       └─► FFmpeg → konversi ke .wav 16kHz mono
            └─► ApiService.predict()
                 └─► POST /predict multipart .wav
                      └─► JSONResponse → EmotionCard

User tekan "Pilih File"
  └─► AudioService.pickAndProcessFile()
       ├─► FilePicker → path file asli
       ├─► FFmpeg → cek durasi
       │    ├─► > 3 detik: crop bagian tengah
       │    └─► ≤ 3 detik: langsung konversi
       └─► konversi ke .wav 16kHz mono
            └─► ApiService.predict() → ...
```

---

## Troubleshooting

**`DioException: Connection refused`**
→ Pastikan server Python sudah jalan dan URL benar

**`Permission denied` saat rekam**
→ Pastikan izin mikrofon diberikan di settings HP

**`FFmpeg error`**
→ Format file tidak didukung. Coba file .mp3 atau .wav

**`InconsistentVersionWarning` di server**
→ Jalankan `pip install scikit-learn==1.6.1` di venv server
