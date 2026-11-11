// Ouvre la version web dans Chromium (rendu logiciel), au format d'un iPhone, attend que le
// jeu tourne, puis enregistre une capture et affiche les messages de la console (erreurs,
// avertissements). Sert à vérifier qu'une version en ligne démarre bien.
//   node tools/web_check.js [url] [capture.png] [secondes]
const { chromium } = require('playwright');
(async () => {
  const url = process.argv[2] || 'https://lulu4660.github.io/Car-idle/';
  const out = process.argv[3] || 'web_check.png';
  const wait = Number(process.argv[4] || 90);
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const logs = [];
  page.on('console', (m) => logs.push(`${m.type()}: ${m.text()}`));
  page.on('pageerror', (e) => logs.push(`pageerror: ${e.message}`));
  await page.goto(url, { waitUntil: 'load', timeout: 120000 });
  await page.waitForTimeout(wait * 1000);
  await page.screenshot({ path: out });
  console.log(logs.join('\n'));
  const bad = logs.filter((l) => l.startsWith('pageerror') || /ERROR|SCRIPT ERROR/.test(l));
  console.log(bad.length ? `\n${bad.length} erreur(s)` : '\naucune erreur');
  await browser.close();
  process.exit(bad.length ? 1 : 0);
})();
