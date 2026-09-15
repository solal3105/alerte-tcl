// Lyon Pocket — interactions

// ---------- Carousel ----------
(function () {
  const track = document.getElementById('track');
  const dotsEl = document.getElementById('dots');
  if (!track) return;

  const slides = Array.from(track.children);
  const prevBtn = document.querySelector('.carousel-prev');
  const nextBtn = document.querySelector('.carousel-next');

  // Build dots
  slides.forEach((_, i) => {
    const b = document.createElement('button');
    b.setAttribute('aria-label', `Aller à l'image ${i + 1}`);
    if (i === 0) b.classList.add('active');
    b.addEventListener('click', () => scrollToSlide(i));
    dotsEl.appendChild(b);
  });
  const dots = Array.from(dotsEl.children);

  function scrollToSlide(i) {
    const slide = slides[i];
    if (!slide) return;
    const offset = slide.offsetLeft - (track.clientWidth - slide.clientWidth) / 2;
    track.scrollTo({ left: offset, behavior: 'smooth' });
  }

  function currentIndex() {
    const center = track.scrollLeft + track.clientWidth / 2;
    let best = 0, bestDist = Infinity;
    slides.forEach((s, i) => {
      const c = s.offsetLeft + s.clientWidth / 2;
      const d = Math.abs(c - center);
      if (d < bestDist) { bestDist = d; best = i; }
    });
    return best;
  }

  track.addEventListener('scroll', () => {
    const i = currentIndex();
    dots.forEach((d, k) => d.classList.toggle('active', k === i));
  }, { passive: true });

  prevBtn?.addEventListener('click', () => scrollToSlide(Math.max(0, currentIndex() - 1)));
  nextBtn?.addEventListener('click', () => scrollToSlide(Math.min(slides.length - 1, currentIndex() + 1)));

  // Autoplay (pauses on hover / touch)
  let autoplay = setInterval(() => {
    const i = currentIndex();
    scrollToSlide((i + 1) % slides.length);
  }, 4500);
  const stop = () => { clearInterval(autoplay); autoplay = null; };
  track.addEventListener('mouseenter', stop);
  track.addEventListener('touchstart', stop, { passive: true });
})();

// ---------- Scroll reveal ----------
(function () {
  const targets = document.querySelectorAll('.feature, .privacy-card, .cta-inner, .section-head, .android-card');
  targets.forEach(el => el.classList.add('reveal'));

  if (!('IntersectionObserver' in window)) {
    targets.forEach(el => el.classList.add('visible'));
    return;
  }
  const io = new IntersectionObserver((entries) => {
    entries.forEach(e => {
      if (e.isIntersecting) {
        e.target.classList.add('visible');
        io.unobserve(e.target);
      }
    });
  }, { threshold: 0.12 });
  targets.forEach(el => io.observe(el));
})();

