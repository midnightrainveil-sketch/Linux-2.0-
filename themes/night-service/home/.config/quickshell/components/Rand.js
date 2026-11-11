.pragma library

// Small seeded PRNG (mulberry32) so hand-made imperfections are stable:
// the same card always has the same cut edge and the same stamp angle.
function make(seed) {
    let a = (seed | 0) ^ 0x9e3779b9;
    return function () {
        a = (a + 0x6D2B79F5) | 0;
        let t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

// Hash a string to a seed.
function hash(str) {
    let h = 2166136261;
    const s = String(str);
    for (let i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i);
        h = Math.imul(h, 16777619);
    }
    return h >>> 0;
}

// Points along a slightly wobbling line from (x0, y0) to (x1, y1).
function wobble(rand, x0, y0, x1, y1, drift, step) {
    const len = Math.hypot(x1 - x0, y1 - y0);
    const n = Math.max(2, Math.ceil(len / step));
    const nx = -(y1 - y0) / (len || 1), ny = (x1 - x0) / (len || 1);
    const pts = [];
    let off = 0;
    for (let i = 0; i <= n; i++) {
        const t = i / n;
        // a random walk, gently pulled back to the ideal line
        off = off * 0.6 + (rand() - 0.5) * drift * 1.4;
        const o = (i === 0 || i === n) ? off * 0.3 : off;
        pts.push([x0 + (x1 - x0) * t + nx * o, y0 + (y1 - y0) * t + ny * o]);
    }
    return pts;
}
