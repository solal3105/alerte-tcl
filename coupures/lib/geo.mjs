// Outils géométriques sans dépendance, à l'échelle d'une agglomération.
// Les distances sont calculées dans une projection équirectangulaire centrée sur Lyon :
// à l'échelle de la Métropole, l'écart avec une distance géodésique reste sous le mètre.

const R = 6371008.8;
const LAT0 = 45.76;
const KX = (Math.PI / 180) * R * Math.cos((LAT0 * Math.PI) / 180);
const KY = (Math.PI / 180) * R;

export const versMetres = ([lon, lat]) => [lon * KX, lat * KY];
export const versLonLat = ([x, y]) => [x / KX, y / KY];

const d2 = (a, b) => (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2;

// Distances cumulées le long d'une polyligne en mètres.
export function cumul(pts) {
  const c = [0];
  for (let i = 1; i < pts.length; i++) c.push(c[i - 1] + Math.sqrt(d2(pts[i - 1], pts[i])));
  return c;
}

// Projette un point sur une polyligne : renvoie la distance le long de la ligne et l'écart.
export function projeter(p, pts, c) {
  let best = { m: 0, ecart: Infinity };
  for (let i = 1; i < pts.length; i++) {
    const a = pts[i - 1], b = pts[i];
    const dx = b[0] - a[0], dy = b[1] - a[1];
    const l2 = dx * dx + dy * dy;
    let t = l2 ? ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2 : 0;
    t = Math.max(0, Math.min(1, t));
    const q = [a[0] + t * dx, a[1] + t * dy];
    const e = Math.sqrt(d2(p, q));
    if (e < best.ecart) best = { m: c[i - 1] + t * Math.sqrt(l2), ecart: e };
  }
  return best;
}

// Extrait la portion de polyligne comprise entre deux distances.
export function decouper(pts, c, m1, m2) {
  const debut = Math.max(0, Math.min(m1, m2));
  const fin = Math.min(c[c.length - 1], Math.max(m1, m2));
  if (fin - debut < 1) return null;
  const interp = (m) => {
    let i = 1;
    while (i < c.length - 1 && c[i] < m) i++;
    const seg = c[i] - c[i - 1] || 1;
    const t = (m - c[i - 1]) / seg;
    return [pts[i - 1][0] + t * (pts[i][0] - pts[i - 1][0]), pts[i - 1][1] + t * (pts[i][1] - pts[i - 1][1])];
  };
  const out = [interp(debut)];
  for (let i = 0; i < pts.length; i++) if (c[i] > debut && c[i] < fin) out.push(pts[i]);
  out.push(interp(fin));
  return out;
}

// Douglas-Peucker sur des points en mètres.
export function simplifier(pts, tol) {
  if (pts.length < 3) return pts;
  const garde = new Uint8Array(pts.length);
  garde[0] = garde[pts.length - 1] = 1;
  const pile = [[0, pts.length - 1]];
  while (pile.length) {
    const [i, j] = pile.pop();
    const a = pts[i], b = pts[j];
    const dx = b[0] - a[0], dy = b[1] - a[1];
    const l = Math.sqrt(dx * dx + dy * dy) || 1;
    let max = 0, k = -1;
    for (let n = i + 1; n < j; n++) {
      const e = Math.abs(dy * pts[n][0] - dx * pts[n][1] + b[0] * a[1] - b[1] * a[0]) / l;
      if (e > max) { max = e; k = n; }
    }
    if (max > tol && k > 0) { garde[k] = 1; pile.push([i, k], [k, j]); }
  }
  return pts.filter((_, n) => garde[n]);
}

// Recolle les morceaux d'un tracé en une seule polyligne : on part du morceau dont le début
// est le plus isolé, puis on rattache à chaque fois le morceau le plus proche, retourné au besoin.
export function recoller(parts) {
  const reste = parts.filter((p) => p.length >= 2).map((p) => p.slice());
  if (reste.length <= 1) return reste[0] || [];
  let iDepart = 0, isolement = -1;
  reste.forEach((p, i) => {
    let proche = Infinity;
    reste.forEach((q, j) => {
      if (i !== j) proche = Math.min(proche, d2(p[0], q[q.length - 1]), d2(p[0], q[0]));
    });
    if (proche > isolement) { isolement = proche; iDepart = i; }
  });
  const ligne = reste.splice(iDepart, 1)[0];
  while (reste.length) {
    const fin = ligne[ligne.length - 1];
    let k = 0, inverse = false, best = Infinity;
    reste.forEach((q, j) => {
      const a = d2(fin, q[0]), b = d2(fin, q[q.length - 1]);
      if (a < best) { best = a; k = j; inverse = false; }
      if (b < best) { best = b; k = j; inverse = true; }
    });
    const q = reste.splice(k, 1)[0];
    if (inverse) q.reverse();
    ligne.push(...(d2(fin, q[0]) < 1 ? q.slice(1) : q));
  }
  return ligne;
}
