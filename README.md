# Mahabbah Kreasi Nusantara — Landing Page

Landing page statis (HTML, CSS, JavaScript murni) yang dijalankan dengan **Docker + Nginx**.
Menampilkan layanan **Desain, Kitchen Set, Furnitur, Baja Ringan, Kanopi, Plafon, dan Pekerjaan Aluminium**
beserta galeri portofolio.

Kontak WhatsApp: **+62 822-2832-9788** (`https://wa.me/6282228329788`)

---

## Struktur Proyek

```
mahabbahkreasinusantara.id/
├── Dockerfile               # Image Nginx + konten statis
├── docker-compose.yml       # Menjalankan container pada port 8080
├── nginx.conf               # Konfigurasi gzip, cache, keamanan
├── .dockerignore
├── scripts/
│   └── prepare-images.ps1   # Menyalin + mengoptimasi gambar & membuat manifest
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
> otomatis menjadi lebih ringan (total ±20 MB untuk 108 gambar) agar
> halaman cepat dibuka.

---

## Kustomisasi Cepat

- **Nomor WhatsApp:** cari `6282228329788` di `public/index.html` dan `public/js/main.js`.
- **Warna & tipografi:** ubah variabel CSS di `:root` pada `public/css/style.css`.
- **Teks layanan / keunggulan:** edit langsung di `public/index.html`.
