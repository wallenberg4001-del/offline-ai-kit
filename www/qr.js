/*
 * Offline AI Kit - tiny QR code maker (byte mode, error correction level M, versions 1-10).
 * Pure JavaScript, no internet, no libraries. Written for the kit following the QR Code standard
 * (ISO/IEC 18004) and the approach of Project Nayuki's MIT-licensed QR generator.
 *   KitQR.encode(text) -> array of rows of booleans (true = dark)
 *   KitQR.svg(text, pixelSize) -> SVG markup string
 * Works in a browser (window.KitQR) and in Node (module.exports) for automated tests.
 */
(function (root) {
  "use strict";
  // Index = version (1..10). Level M only.
  var ECC_PER_BLOCK = [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26];
  var NUM_BLOCKS = [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5];
  var FORMAT_ECL_M = 0;

  function rawModules(ver) {
    var r = (16 * ver + 128) * ver + 64;
    if (ver >= 2) { var na = Math.floor(ver / 7) + 2; r -= (25 * na - 10) * na - 55; if (ver >= 7) r -= 36; }
    return r;
  }
  function dataCodewords(ver) { return Math.floor(rawModules(ver) / 8) - ECC_PER_BLOCK[ver] * NUM_BLOCKS[ver]; }
  function gfMul(x, y) { var z = 0; for (var i = 7; i >= 0; i--) { z = (z << 1) ^ ((z >>> 7) * 0x11D); z ^= ((y >>> i) & 1) * x; } return z & 0xFF; }
  function rsDivisor(deg) {
    var r = []; for (var i = 0; i < deg - 1; i++) r.push(0); r.push(1);
    var rt = 1;
    for (i = 0; i < deg; i++) {
      for (var j = 0; j < r.length; j++) { r[j] = gfMul(r[j], rt); if (j + 1 < r.length) r[j] ^= r[j + 1]; }
      rt = gfMul(rt, 0x02);
    }
    return r;
  }
  function rsRemainder(data, div) {
    var r = div.map(function () { return 0; });
    data.forEach(function (b) {
      var f = b ^ r.shift(); r.push(0);
      div.forEach(function (c, i) { r[i] ^= gfMul(c, f); });
    });
    return r;
  }
  function utf8(text) {
    var out = [], s = unescape(encodeURIComponent(String(text)));
    for (var i = 0; i < s.length; i++) out.push(s.charCodeAt(i));
    return out;
  }

  function encode(text) {
    var bytes = utf8(text), ver, i;
    for (ver = 1; ver <= 10; ver++) {
      var ccBits = ver < 10 ? 8 : 16;
      if (4 + ccBits + bytes.length * 8 <= dataCodewords(ver) * 8) break;
    }
    if (ver > 10) throw new Error("Text too long for a QR code");
    var cap = dataCodewords(ver) * 8, bits = [];
    function put(val, len) { for (var k = len - 1; k >= 0; k--) bits.push((val >>> k) & 1); }
    put(4, 4); put(bytes.length, ver < 10 ? 8 : 16);
    bytes.forEach(function (b) { put(b, 8); });
    put(0, Math.min(4, cap - bits.length));
    put(0, (8 - bits.length % 8) % 8);
    for (var pad = 0xEC; bits.length < cap; pad ^= 0xEC ^ 0x11) put(pad, 8);
    var data = [];
    for (i = 0; i < bits.length; i += 8) { var v = 0; for (var k = 0; k < 8; k++) v = (v << 1) | bits[i + k]; data.push(v); }

    // Error correction blocks, interleaved.
    var nb = NUM_BLOCKS[ver], el = ECC_PER_BLOCK[ver], raw = Math.floor(rawModules(ver) / 8);
    var nShort = nb - raw % nb, shortLen = Math.floor(raw / nb), div = rsDivisor(el), blocks = [], pos = 0;
    for (i = 0; i < nb; i++) {
      var dat = data.slice(pos, pos + shortLen - el + (i < nShort ? 0 : 1)); pos += dat.length;
      var ecc = rsRemainder(dat, div);
      if (i < nShort) dat.push(0);
      blocks.push(dat.concat(ecc));
    }
    var all = [];
    for (i = 0; i < blocks[0].length; i++) for (var j = 0; j < blocks.length; j++) if (i !== shortLen - el || j >= nShort) all.push(blocks[j][i]);

    var size = ver * 4 + 17, mod = [], fn = [];
    for (i = 0; i < size; i++) { mod.push([]); fn.push([]); for (j = 0; j < size; j++) { mod[i].push(false); fn[i].push(false); } }
    function setF(x, y, dark) { mod[y][x] = dark; fn[y][x] = true; }
    for (i = 0; i < size; i++) { setF(6, i, i % 2 === 0); setF(i, 6, i % 2 === 0); }
    [[3, 3], [size - 4, 3], [3, size - 4]].forEach(function (c) {
      for (var dy = -4; dy <= 4; dy++) for (var dx = -4; dx <= 4; dx++) {
        var d = Math.max(Math.abs(dx), Math.abs(dy)), xx = c[0] + dx, yy = c[1] + dy;
        if (xx >= 0 && xx < size && yy >= 0 && yy < size) setF(xx, yy, d !== 2 && d !== 4);
      }
    });
    var al = [];
    if (ver > 1) {
      var na = Math.floor(ver / 7) + 2, step = Math.ceil((ver * 4 + 4) / (na * 2 - 2)) * 2;
      al = [6];
      for (var p = size - 7; al.length < na; p -= step) al.splice(1, 0, p);
    }
    for (i = 0; i < al.length; i++) for (j = 0; j < al.length; j++) {
      if ((i === 0 && j === 0) || (i === 0 && j === al.length - 1) || (i === al.length - 1 && j === 0)) continue;
      for (var ay = -2; ay <= 2; ay++) for (var ax = -2; ax <= 2; ax++) setF(al[i] + ax, al[j] + ay, Math.max(Math.abs(ax), Math.abs(ay)) !== 1);
    }
    function drawFormat(mask) {
      var d = (FORMAT_ECL_M << 3) | mask, r = d;
      for (var q = 0; q < 10; q++) r = (r << 1) ^ ((r >>> 9) * 0x537);
      var b = ((d << 10) | r) ^ 0x5412;
      function bit(n) { return ((b >>> n) & 1) !== 0; }
      for (q = 0; q <= 5; q++) setF(8, q, bit(q));
      setF(8, 7, bit(6)); setF(8, 8, bit(7)); setF(7, 8, bit(8));
      for (q = 9; q < 15; q++) setF(14 - q, 8, bit(q));
      for (q = 0; q < 8; q++) setF(size - 1 - q, 8, bit(q));
      for (q = 8; q < 15; q++) setF(8, size - 15 + q, bit(q));
      setF(8, size - 8, true);
    }
    drawFormat(0);
    if (ver >= 7) {
      var rv = ver; for (i = 0; i < 12; i++) rv = (rv << 1) ^ ((rv >>> 11) * 0x1F25);
      var vb = (ver << 12) | rv;
      for (i = 0; i < 18; i++) { var bt = ((vb >>> i) & 1) !== 0, a = size - 11 + i % 3, c2 = Math.floor(i / 3); setF(a, c2, bt); setF(c2, a, bt); }
    }
    // Data bits in the zig-zag order.
    var bi = 0;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right === 6) right = 5;
      for (var vert = 0; vert < size; vert++) for (j = 0; j < 2; j++) {
        var x = right - j, up = ((right + 1) & 2) === 0, y = up ? size - 1 - vert : vert;
        if (!fn[y][x] && bi < all.length * 8) { mod[y][x] = ((all[bi >>> 3] >>> (7 - (bi & 7))) & 1) !== 0; bi++; }
      }
    }
    function maskBit(m, x, y) {
      switch (m) {
        case 0: return (x + y) % 2 === 0; case 1: return y % 2 === 0; case 2: return x % 3 === 0; case 3: return (x + y) % 3 === 0;
        case 4: return (Math.floor(x / 3) + Math.floor(y / 2)) % 2 === 0; case 5: return x * y % 2 + x * y % 3 === 0;
        case 6: return (x * y % 2 + x * y % 3) % 2 === 0; default: return ((x + y) % 2 + x * y % 3) % 2 === 0;
      }
    }
    function applyMask(m) { for (var yy = 0; yy < size; yy++) for (var xx = 0; xx < size; xx++) if (!fn[yy][xx] && maskBit(m, xx, yy)) mod[yy][xx] = !mod[yy][xx]; }
    function penalty() {
      var s = 0, yy, xx, dark = 0;
      function lines(get) {
        for (var a = 0; a < size; a++) {
          var run = 1, str = "";
          for (var b = 0; b < size; b++) {
            str += get(a, b) ? "1" : "0";
            if (b > 0) { if (get(a, b) === get(a, b - 1)) { run++; if (run === 5) s += 3; else if (run > 5) s++; } else run = 1; }
          }
          var re = /(?=(10111010000|00001011101))/g, mm;
          while ((mm = re.exec(str)) !== null) { s += 40; re.lastIndex++; }
        }
      }
      lines(function (a, b) { return mod[a][b]; });
      lines(function (a, b) { return mod[b][a]; });
      for (yy = 0; yy < size - 1; yy++) for (xx = 0; xx < size - 1; xx++) {
        var c = mod[yy][xx];
        if (c === mod[yy][xx + 1] && c === mod[yy + 1][xx] && c === mod[yy + 1][xx + 1]) s += 3;
      }
      for (yy = 0; yy < size; yy++) for (xx = 0; xx < size; xx++) if (mod[yy][xx]) dark++;
      var total = size * size;
      s += Math.floor(Math.abs(dark * 20 - total * 10) / total) * 10;
      return s;
    }
    var best = 0, bestP = Infinity;
    for (var m = 0; m < 8; m++) {
      applyMask(m); drawFormat(m);
      var pen = penalty();
      if (pen < bestP) { bestP = pen; best = m; }
      applyMask(m);
    }
    applyMask(best); drawFormat(best);
    return mod;
  }

  function svg(text, px) {
    var m = encode(text), n = m.length, q = 4, d = "";
    for (var y = 0; y < n; y++) for (var x = 0; x < n; x++) if (m[y][x]) d += "M" + (x + q) + " " + (y + q) + "h1v1h-1z";
    var w = (n + q * 2) * (px || 4);
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + (n + q * 2) + " " + (n + q * 2) + '" width="' + w + '" height="' + w +
      '" shape-rendering="crispEdges" role="img"><rect width="100%" height="100%" fill="#fff"/><path d="' + d + '" fill="#000"/></svg>';
  }

  var api = { encode: encode, svg: svg };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.KitQR = api;
})(typeof window !== "undefined" ? window : this);
