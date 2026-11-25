/* =========================================================
   PRGS · Animaciones (scroll, contadores, FAQ, precios)
   ========================================================= */
(() => {
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const $  = (s, ctx = document) => ctx.querySelector(s);
  const $$ = (s, ctx = document) => [...ctx.querySelectorAll(s)];
  const easeOut = t => 1 - Math.pow(1 - t, 3);

  /* ---------- Header con fondo al scrollear (vale también sin animaciones) ---------- */
  const header = $('.header');
  const onScroll = () => header.classList.toggle('is-scrolled', window.scrollY > 8);
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  if (reduce) return;
  document.documentElement.classList.add('anim-ready');

  /* ---------- Qué aparece al scrollear ---------- */
  const singles = [
    '.section-intro',
    '.billing',
    '.progress-preview',
    '.chart',
    '.load__change',
    '.workspace',
    '.trainer__message > .btn',
    '.photo-review',
    '.pricing-conditions',
    '.plan-free',
    '.includes__title',
    '.services__intro',
    '.role-toggle',
    '.faq__intro .link-accent',
    '.cta-final__title',
    '.cta-final__text',
    '.cta-final .btn',
    '.footer__brand',
  ];
  const groups = [
    '.facts',
    '.benefits',
    '.trainer-tools',
    '.plans',
    '.stories',
    '.faq__list',
    '.students',
    '.sessions',
    '.footer__links',
    '.includes__grid',
    '.services__list',
    '.screens__track',
  ];

  // .chart y .load__change solo necesitan la clase is-visible (su animación es propia)
  const ownAnim = new Set(['.chart', '.load__change']);

  const targets = [];
  singles.forEach(sel => $$(sel).forEach(el => {
    if (!ownAnim.has(sel)) el.setAttribute('data-reveal', '');
    targets.push(el);
  }));
  groups.forEach(sel => $$(sel).forEach(el => {
    el.setAttribute('data-reveal-group', '');
    [...el.children].forEach((child, i) => child.style.setProperty('--i', i));
    targets.push(el);
  }));

  const io = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      const el = entry.target;
      el.classList.add('is-visible');
      el.dispatchEvent(new CustomEvent('reveal'));
      io.unobserve(el);
    });
  }, { threshold: 0.15, rootMargin: '0px 0px -8% 0px' });
  targets.forEach(el => io.observe(el));

  /* ---------- Contadores ---------- */
  function countUp(node, from, to, duration = 1200) {
    // node: nodo de texto; mantiene lo que viene después del número
    const rest = node.nodeValue.replace(/^\s*\d+/, '');
    const start = performance.now();
    const tick = now => {
      const t = Math.min(1, (now - start) / duration);
      node.nodeValue = Math.round(from + (to - from) * easeOut(t)) + rest;
      if (t < 1) requestAnimationFrame(tick);
    };
    node.nodeValue = from + rest;
    requestAnimationFrame(tick);
  }

  // "3 datos", "1 timer", "2 roles"
  const facts = $('.facts');
  if (facts) facts.addEventListener('reveal', () => {
    $$('.fact strong', facts).forEach((el, i) => {
      const node = el.firstChild;
      const m = node && node.nodeValue.match(/^\s*(\d+)/);
      if (m) setTimeout(() => countUp(node, 0, +m[1], 900), i * 90);
    });
  }, { once: true });

  // "60 kg" sube junto con la línea del gráfico
  const loadValue = $('.load__value');
  const chart = $('.chart');
  if (loadValue && chart) chart.addEventListener('reveal', () => {
    const node = loadValue.firstChild;
    const m = node.nodeValue.match(/^\s*(\d+)/);
    if (m) setTimeout(() => countUp(node, +m[1] - 15, +m[1], 1500), 200);
  }, { once: true });

  /* ---------- Tabs del gráfico: redibujar la línea ---------- */
  const line = $('.chart__line');
  $$('.tabs .tab').forEach(tab => tab.addEventListener('click', () => {
    if (!line) return;
    line.animate(
      [{ strokeDashoffset: 1 }, { strokeDashoffset: 0 }],
      { duration: 1200, easing: 'cubic-bezier(.65,0,.35,1)' }
    );
  }));

  /* ---------- Precios: transición al cambiar Mensual / Anual ---------- */
  $$('.billing__opt').forEach(btn => btn.addEventListener('click', () => {
    $$('.price__amount').forEach((el, i) => el.animate(
      [
        { opacity: 0, transform: 'translateY(10px)', filter: 'blur(4px)' },
        { opacity: 1, transform: 'none', filter: 'blur(0)' }
      ],
      { duration: 420, delay: i * 60, easing: 'cubic-bezier(.22,1,.36,1)', fill: 'backwards' }
    ));
  }));

  /* ---------- FAQ: abrir y cerrar con altura animada ---------- */
  $$('.faq-item').forEach(item => {
    const summary = $('summary', item);
    const answer = $('p', item);
    let busy = false;

    summary.addEventListener('click', e => {
      e.preventDefault();
      if (busy) return;
      busy = true;
      answer.style.overflow = 'hidden';

      if (item.open) {
        const h = answer.offsetHeight;
        answer.animate(
          [
            { height: h + 'px', marginTop: '16px', opacity: 1 },
            { height: '0px', marginTop: '0px', opacity: 0 }
          ],
          { duration: 320, easing: 'cubic-bezier(.65,0,.35,1)' }
        ).onfinish = () => { item.open = false; answer.style.overflow = ''; busy = false; };
      } else {
        item.open = true;
        const h = answer.offsetHeight;
        answer.animate(
          [
            { height: '0px', marginTop: '0px', opacity: 0 },
            { height: h + 'px', marginTop: '16px', opacity: 1 }
          ],
          { duration: 380, easing: 'cubic-bezier(.22,1,.36,1)' }
        ).onfinish = () => { answer.style.overflow = ''; busy = false; };
      }
    });
  });

  /* ---------- Hero: los celulares siguen un poco al mouse (solo desktop) ---------- */
  const showcase = $('.showcase');
  if (showcase && window.matchMedia('(hover: hover) and (min-width: 1025px)').matches) {
    const phones = $$('.phone', showcase);
    let raf = null;
    showcase.addEventListener('pointermove', e => {
      const r = showcase.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5;
      const y = (e.clientY - r.top) / r.height - 0.5;
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => phones.forEach((p, i) => {
        const depth = i === 0 ? 10 : 18;
        p.style.marginLeft = (x * depth) + 'px';
        p.style.marginTop = (y * depth) + 'px';
      }));
    });
    showcase.addEventListener('pointerleave', () => phones.forEach(p => {
      p.style.marginLeft = '';
      p.style.marginTop = '';
    }));
  }
})();
