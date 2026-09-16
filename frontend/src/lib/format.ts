// Formatter bersama. Aturannya sama dengan ApplicationHelper di sisi Rails:
// pemisah ribuan titik, desimal koma, dan U+2212 untuk negatif supaya lebar
// tandanya sejajar dengan digit tabular.

const MINUS = "−";

export function idr(n: number): string {
  return new Intl.NumberFormat("id-ID").format(Math.round(n));
}

export function num(n: number): string {
  return new Intl.NumberFormat("id-ID").format(n);
}

/** Desimal gaya Indonesia. null -> em dash, bukan "0" — tak tahu bukan nol. */
export function dec(v: number | null | undefined, digits = 2): string {
  if (v === null || v === undefined || Number.isNaN(v)) return "—";
  return v.toFixed(digits).replace("-", MINUS).replace(".", ",");
}

/**
 * Persen bertanda. Nol TIDAK diberi tanda: "+0,00%" menyiratkan kenaikan yang
 * tidak terjadi.
 */
export function signedPct(v: number | null | undefined, digits = 2): string {
  if (v === null || v === undefined || Number.isNaN(v)) return "—";
  const r = Number(v.toFixed(digits));
  const body = Math.abs(r).toFixed(digits).replace(".", ",");
  if (r === 0) return `${body}%`;
  return `${r < 0 ? MINUS : "+"}${body}%`;
}

/** Kelas arah. null dan nol sama-sama netral — nol bukan kenaikan. */
export function dirClass(v: number | null | undefined): string {
  if (v === null || v === undefined || v === 0) return "ink";
  return v < 0 ? "fall" : "rise";
}

export function timeAgo(iso: string): string {
  const mins = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
  if (mins < 1) return "baru saja";
  if (mins < 60) return `${mins} menit lalu`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours} jam lalu`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days} hari lalu`;
  const months = Math.floor(days / 30);
  return months < 12 ? `${months} bulan lalu` : `${Math.floor(months / 12)} tahun lalu`;
}

/** Jam Jakarta — pembaca ada di WIB, server dan browser belum tentu. */
export function jakartaTime(iso: string): string {
  return new Intl.DateTimeFormat("id-ID", {
    day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit",
    timeZone: "Asia/Jakarta", hour12: false,
  }).format(new Date(iso));
}
