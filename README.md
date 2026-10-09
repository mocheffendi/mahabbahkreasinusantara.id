# Mahabbah Kreasi Nusantara — Landing Page

Landing page statis (HTML, CSS, JavaScript murni) yang dijalankan dengan **Docker + Nginx**.
Menampilkan layanan **Desain, Kitchen Set, Furnitur, Baja Ringan, Kanopi, Plafon, dan Pekerjaan Aluminium**
beserta galeri portofolio.

Kontak WhatsApp: **+62 822-2832-9788** (`https://wa.me/6282228329788`)

---

## Struktur Proyek

```
mahabbahkreasinusantara.id/
├── Dockerfile                    # Image Nginx + konten statis
├── docker-compose.yml            # Lokal: build & jalankan pada port 8080
├── docker-compose.prod.yml       # Server: pull image dari GHCR (tanpa build)
├── nginx.conf                    # Konfigurasi gzip, cache, keamanan
├── .dockerignore / .gitignore / .gitattributes
├── .github/workflows/deploy.yml  # CI/CD: test → build → push GHCR → deploy via SSH
├── scripts/
│   ├── prepare-images.ps1        # Salin + optimasi gambar & buat manifest
│   └── test.sh                   # Pengujian ringan (dipakai CI)
└── public/
    ├── index.html           # Halaman utama
    ├── css/style.css
    ├── js/main.js
    └── images/
        ├── thumbs/<grup>/   # Thumbnail galeri (max 640px)
        ├── full/<grup>/     # Gambar besar untuk lightbox (max 1600px)
        └── manifest.json    # Daftar gambar per kategori
```

Kategori gambar: `desain-rumah`, `desain-kitchen-set`, `desain-backdrop-tv`,
`kitchen-set`, `furnitur-meja`, `furnitur-mihrab`, `baja-ringan`, `kanopi`,
`plafon`, `aluminium-kusen`.

---

## Menjalankan dengan Docker

### Cara 1 — Docker Compose (disarankan)

```bash
docker compose up -d --build
```

Buka: http://localhost:8080

Hentikan:

```bash
docker compose down
```

### Cara 2 — Docker biasa

```bash
docker build -t mahabbahkreasinusantara-web .
docker run -d -p 8080:80 --name mahabbahkreasinusantara mahabbahkreasinusantara-web
```

---

## Memperbarui Gambar

1. Letakkan/ubah gambar pada folder sumber, lalu sesuaikan daftar `$Groups`
   di `scripts/prepare-images.ps1` bila perlu.
2. Jalankan:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-images.ps1
```

Skrip akan menyalin, mengecilkan ukuran (thumbnail + versi besar), dan
menulis ulang `public/images/manifest.json`.
3. Build ulang container: `docker compose up -d --build`.

> Catatan: gambar sumber asli dapat berukuran >10 MB, sehingga dioptimasi
> otomatis menjadi lebih ringan (total ±20 MB untuk 107 gambar) agar
> halaman cepat dibuka. Gambar yang terdeteksi rusak akan dilewati otomatis.

---

## CI/CD (GitHub Actions)

Workflow `.github/workflows/deploy.yml` berjalan otomatis setiap push ke `main`:

| # | Tahap | Keterangan |
|---|-------|------------|
| 1 | **Checkout source** | Ambil kode dari repository |
| 2 | **Test** | `bash scripts/test.sh` (cek file, manifest JSON, aset, nomor WA, line ending) |
| 3 | **Docker build** | Build image dengan Buildx (cache GitHub Actions) |
| 4 | **Docker push** | Push ke **GHCR**: `ghcr.io/<owner>/<repo>` (tag `latest` + `sha-<commit>`) |
| 5 | **SSH ke server** | Salin `docker-compose.prod.yml` & login GHCR (bila perlu) |
| 6 | **`docker compose pull`** | Tarik image terbaru |
| 7 | **`docker compose up -d`** | Jalankan/refresh container di server |

### Secrets & Variables yang perlu diisi

Buka **GitHub → Settings → Secrets and variables → Actions**.

**Secrets:**

| Nama | Wajib | Keterangan |
|------|:-----:|------------|
| `SSH_HOST` | ✅ | IP/domain server |
| `SSH_USER` | ✅ | User SSH (harus bisa menjalankan `docker`) |
| `SSH_PRIVATE_KEY` | ✅ | Private key SSH (isi lengkap, termasuk header) |
| `SSH_PORT` | ✖ | Default `22` |
| `DEPLOY_PATH` | ✖ | Default `/opt/mahabbahkreasinusantara` |
| `GHCR_USER` | ✖ | Username GitHub — untuk pull package **privat** |
| `GHCR_TOKEN` | ✖ | PAT dengan scope `read:packages` — untuk package **privat** |

**Variables:**

| Nama | Nilai | Keterangan |
|------|-------|------------|
| `DEPLOY_ENABLED` | `true` | Mengaktifkan tahap deploy (5–7). Jika belum di-set, deploy dilewati sehingga CI tetap hijau. |

> **Package privat:** secara default image GHCR bersifat privat. Pilih salah satu:
> 1. Buat package publik di GitHub (Package settings → Change visibility → Public), **atau**
> 2. Isi `GHCR_USER` + `GHCR_TOKEN` agar server bisa `docker login ghcr.io` saat deploy.

### Deploy manual di server

```bash
cd /opt/mahabbahkreasinusantara
cp docker-compose.prod.yml docker-compose.yml
IMAGE_REF=ghcr.io/mocheffendi/mahabbahkreasinusantara.id:latest docker compose pull
IMAGE_REF=ghcr.io/mocheffendi/mahabbahkreasinusantara.id:latest docker compose up -d
```

---

## Kustomisasi Cepat

- **Nomor WhatsApp:** cari `6282228329788` di `public/index.html` dan `public/js/main.js`.
- **Warna & tipografi:** ubah variabel CSS di `:root` pada `public/css/style.css`.
- **Teks layanan / keunggulan:** edit langsung di `public/index.html`.
