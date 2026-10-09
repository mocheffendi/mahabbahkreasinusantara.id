/* =========================================================
   Mahabbah Kreasi Nusantara — main.js
   ========================================================= */
(function () {
  "use strict";

  var WA_NUMBER = "6282228329788";

  /* ---------- Tahun footer ---------- */
  var yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  /* ---------- Header scroll ---------- */
  var header = document.getElementById("header");
  function onScroll() {
    if (window.scrollY > 40) header.classList.add("scrolled");
    else header.classList.remove("scrolled");
  }
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  /* ---------- Mobile nav ---------- */
  var navToggle = document.getElementById("navToggle");
  var nav = document.getElementById("nav");
  function closeNav() {
    nav.classList.remove("open");
    navToggle.classList.remove("open");
    navToggle.setAttribute("aria-expanded", "false");
  }
  navToggle.addEventListener("click", function () {
    var isOpen = nav.classList.toggle("open");
    navToggle.classList.toggle("open", isOpen);
    navToggle.setAttribute("aria-expanded", String(isOpen));
  });
  nav.querySelectorAll("a").forEach(function (a) {
    a.addEventListener("click", closeNav);
  });

  /* ---------- Reveal on scroll ---------- */
  var revealEls = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -40px 0px" });
    revealEls.forEach(function (el) { io.observe(el); });
  } else {
    revealEls.forEach(function (el) { el.classList.add("is-visible"); });
  }

  /* ---------- Data kategori ---------- */
  var GROUP_LABEL = {
    "desain-rumah": "Desain Rumah",
    "desain-kitchen-set": "Desain Kitchen Set",
    "desain-backdrop-tv": "Desain Backdrop TV",
    "kitchen-set": "Kitchen Set",
    "furnitur-meja": "Furnitur Meja",
    "furnitur-mihrab": "Mihrab",
    "baja-ringan": "Baja Ringan",
    "kanopi": "Kanopi",
    "plafon": "Plafon",
    "aluminium-kusen": "Kusen & Aluminium"
  };

  var CATEGORIES = [
    { id: "semua", label: "Semua", groups: Object.keys(GROUP_LABEL) },
    { id: "desain", label: "Desain", groups: ["desain-rumah", "desain-kitchen-set", "desain-backdrop-tv"] },
    { id: "kitchen-set", label: "Kitchen Set", groups: ["kitchen-set"] },
    { id: "furnitur", label: "Furnitur", groups: ["furnitur-meja", "furnitur-mihrab"] },
    { id: "baja-ringan", label: "Baja Ringan", groups: ["baja-ringan"] },
    { id: "kanopi", label: "Kanopi", groups: ["kanopi"] },
    { id: "plafon", label: "Plafon", groups: ["plafon"] },
    { id: "aluminium", label: "Aluminium", groups: ["aluminium-kusen"] }
  ];

  var PAGE_SIZE = 12;

  var galleryEl = document.getElementById("gallery");
  var filterEl = document.getElementById("filter");
  var loadMoreBtn = document.getElementById("loadMore");

  var allItems = [];
  var currentFiltered = [];
  var activeCat = "semua";
  var shownCount = PAGE_SIZE;

  /* ---------- Init ---------- */
  fetch("images/manifest.json")
    .then(function (res) {
      if (!res.ok) throw new Error("Gagal memuat manifest");
      return res.json();
    })
    .then(function (manifest) {
      buildItems(manifest);
      buildFilter();
      applyFilter("semua", true);
    })
    .catch(function (err) {
      console.error(err);
      galleryEl.innerHTML = '<p class="gallery-empty">Galeri tidak dapat dimuat saat ini.</p>';
    });

  function buildItems(manifest) {
    CATEGORIES.forEach(function (cat) {
      if (cat.id === "semua") return;
      cat.groups.forEach(function (group) {
        var list = manifest[group] || [];
        list.forEach(function (entry) {
          allItems.push({
            cat: cat.id,
            group: group,
            label: GROUP_LABEL[group] || group,
            thumb: entry.thumb,
            full: entry.full
          });
        });
      });
    });
  }

  function buildFilter() {
    CATEGORIES.forEach(function (cat) {
      var count = cat.id === "semua"
        ? allItems.length
        : allItems.filter(function (it) { return it.cat === cat.id; }).length;
      if (!count) return;

      var btn = document.createElement("button");
      btn.type = "button";
      btn.dataset.cat = cat.id;
      btn.setAttribute("role", "tab");
      btn.innerHTML = cat.label + ' <span style="opacity:.55">(' + count + ")</span>";
      btn.addEventListener("click", function () { applyFilter(cat.id, true); });
      filterEl.appendChild(btn);
    });
  }

  function applyFilter(catId, reset) {
    activeCat = catId;
    if (reset) shownCount = PAGE_SIZE;

    filterEl.querySelectorAll("button").forEach(function (b) {
      b.classList.toggle("active", b.dataset.cat === catId);
      b.setAttribute("aria-selected", String(b.dataset.cat === catId));
    });

    currentFiltered = catId === "semua"
      ? allItems.slice()
      : allItems.filter(function (it) { return it.cat === catId; });

    renderGallery(true);
  }

  function renderGallery(clear) {
    if (clear) galleryEl.innerHTML = "";

    var slice = currentFiltered.slice(clear ? 0 : galleryEl.childElementCount, shownCount);
    var frag = document.createDocumentFragment();

    slice.forEach(function (item, i) {
      var index = (clear ? 0 : galleryEl.childElementCount) + i;

      var fig = document.createElement("div");
      fig.className = "gallery-item";
      fig.style.animationDelay = (Math.min(i, 10) * 0.04) + "s";
      fig.setAttribute("role", "button");
      fig.setAttribute("tabindex", "0");
      fig.setAttribute("aria-label", "Perbesar " + item.label);

      var img = document.createElement("img");
      img.src = item.thumb;
      img.alt = item.label + " — Mahabbah Kreasi Nusantara";
      img.loading = "lazy";
      img.decoding = "async";

      var zoom = document.createElement("span");
      zoom.className = "gi-zoom";
      zoom.innerHTML = '<svg viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M15.5 14h-.8l-.3-.3a6.5 6.5 0 1 0-.7.7l.3.3v.8l5 5 1.5-1.5-5-5zm-6 0A4.5 4.5 0 1 1 14 9.5 4.5 4.5 0 0 1 9.5 14z"/></svg>';

      var info = document.createElement("div");
      info.className = "gi-info";
      info.innerHTML = "<span>Portofolio</span><strong>" + item.label + "</strong>";

      fig.appendChild(img);
      fig.appendChild(zoom);
      fig.appendChild(info);

      fig.addEventListener("click", function () { openLightbox(index); });
      fig.addEventListener("keydown", function (e) {
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); openLightbox(index); }
      });

      frag.appendChild(fig);
    });

    galleryEl.appendChild(frag);

    if (shownCount >= currentFiltered.length) loadMoreBtn.hidden = true;
    else loadMoreBtn.hidden = false;
  }

  loadMoreBtn.addEventListener("click", function () {
    shownCount += PAGE_SIZE;
    renderGallery(false);
  });

  /* ---------- Lightbox ---------- */
  var lightbox = document.getElementById("lightbox");
  var lbImg = document.getElementById("lbImg");
  var lbCaption = document.getElementById("lbCaption");
  var lbClose = document.getElementById("lbClose");
  var lbPrev = document.getElementById("lbPrev");
  var lbNext = document.getElementById("lbNext");
  var lbIndex = 0;
  var lastFocused = null;

  function openLightbox(index) {
    if (!currentFiltered.length) return;
    lbIndex = index;
    lastFocused = document.activeElement;
    updateLightbox();
    lightbox.classList.add("open");
    lightbox.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";
    lbClose.focus();
  }

  function updateLightbox() {
    var item = currentFiltered[lbIndex];
    if (!item) return;
    lbImg.src = item.full;
    lbImg.alt = item.label + " — Mahabbah Kreasi Nusantara";
    lbCaption.textContent = item.label + "  ·  " + (lbIndex + 1) + " / " + currentFiltered.length;
    var single = currentFiltered.length <= 1;
    lightbox.classList.toggle("no-nav", single);
  }

  function closeLightbox() {
    lightbox.classList.remove("open");
    lightbox.setAttribute("aria-hidden", "true");
    document.body.style.overflow = "";
    lbImg.src = "";
    if (lastFocused && lastFocused.focus) lastFocused.focus();
  }

  function nextImage(dir) {
    if (!currentFiltered.length) return;
    lbIndex = (lbIndex + dir + currentFiltered.length) % currentFiltered.length;
    updateLightbox();
  }

  lbClose.addEventListener("click", closeLightbox);
  lbPrev.addEventListener("click", function () { nextImage(-1); });
  lbNext.addEventListener("click", function () { nextImage(1); });
  lightbox.addEventListener("click", function (e) {
    if (e.target === lightbox) closeLightbox();
  });
  document.addEventListener("keydown", function (e) {
    if (!lightbox.classList.contains("open")) return;
    if (e.key === "Escape") closeLightbox();
    else if (e.key === "ArrowLeft") nextImage(-1);
    else if (e.key === "ArrowRight") nextImage(1);
  });

  /* Swipe support untuk lightbox */
  var touchX = null;
  lightbox.addEventListener("touchstart", function (e) { touchX = e.changedTouches[0].clientX; }, { passive: true });
  lightbox.addEventListener("touchend", function (e) {
    if (touchX === null) return;
    var dx = e.changedTouches[0].clientX - touchX;
    if (Math.abs(dx) > 50) nextImage(dx < 0 ? 1 : -1);
    touchX = null;
  }, { passive: true });

  /* ---------- Smooth anchor offset untuk header ---------- */
  document.querySelectorAll('a[href^="#"]').forEach(function (link) {
    link.addEventListener("click", function (e) {
      var id = link.getAttribute("href");
      if (id.length < 2) return;
      var target = document.querySelector(id);
      if (!target) return;
      e.preventDefault();
      var top = target.getBoundingClientRect().top + window.scrollY - 70;
      window.scrollTo({ top: top, behavior: "smooth" });
    });
  });
})();
