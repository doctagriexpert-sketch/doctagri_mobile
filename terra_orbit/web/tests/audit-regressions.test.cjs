const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('typescript');
const { NextRequest } = require('next/server');

function load(relative, aliases = {}) {
  const filename = path.resolve(__dirname, '..', relative);
  const m = new Module(filename, module);
  m.filename = filename;
  m.paths = module.paths;
  const original = m.require.bind(m);
  m.require = id => Object.hasOwn(aliases, id) ? aliases[id] : original(id);
  m._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
      jsx: ts.JsxEmit.ReactJSX, esModuleInterop: true },
  }).outputText, filename);
  return m.exports;
}

async function callRoute(route, provider) {
  const original = global.fetch;
  global.fetch = async url => ({ ok: true, json: async () => provider(new URL(url)) });
  try {
    const response = await load(route).GET(new NextRequest('http://localhost/api/test?lat=10.8631&lon=0.2078'));
    return { status: response.status, body: await response.json() };
  } finally { global.fetch = original; }
}

function nasaPayload(url, rains) {
  const start = url.searchParams.get('start');
  const date = new Date(`${start.slice(0, 4)}-${start.slice(4, 6)}-${start.slice(6, 8)}T00:00:00Z`);
  const parameter = { T2M: {}, PRECTOTCORR: {} };
  rains.forEach(rain => {
    const key = date.toISOString().slice(0, 10).replaceAll('-', '');
    parameter.T2M[key] = 28;
    parameter.PRECTOTCORR[key] = rain;
    date.setUTCDate(date.getUTCDate() + 1);
  });
  return { properties: { parameter } };
}

const nasaRoute = 'src/app/api/nasa-power/route.ts';
test('an unknown rainy day breaks consecutive drought evidence', async () => {
  const { body } = await callRoute(nasaRoute, url => nasaPayload(url, [0,0,0,0,-999,0,0,0,0]));
  assert.equal(body.summary.maxDrySpellDays, 4);
});
test('missing min/max temperatures stay unknown', async () => {
  const { body } = await callRoute(nasaRoute, url => nasaPayload(url, [5]));
  assert.equal(body.series[0].tempMax, null);
  assert.equal(body.series[0].tempMin, null);
});
test('an empty soil response cannot become live telemetry', async () => {
  const { status, body } = await callRoute('src/app/api/satellite-soil-moisture/route.ts', () => ({}));
  assert.equal(status, 502);
  assert.equal(body.liveTelemetry, undefined);
});
test('an empty NASA response is unavailable', async () => {
  const { status } = await callRoute(nasaRoute, () => ({}));
  assert.equal(status, 502);
});

test('a date absent from all maps also breaks dry continuity', async () => {
  const { body } = await callRoute(nasaRoute, url => {
    const value = nasaPayload(url, [0,0,0,0,0,0,0,0,0]);
    for (const map of Object.values(value.properties.parameter)) delete map[Object.keys(map)[4]];
    return value;
  });
  assert.equal(body.summary.maxDrySpellDays, 4);
  assert.equal(body.periodDays, 30);
  assert.equal(body.series[4].rainMm, null);
});

test('zero soil moisture is valid and never replaced by a default', async () => {
  const { status, body } = await callRoute('src/app/api/satellite-soil-moisture/route.ts', () => ({
    hourly: { time: [new Date().toISOString().slice(0, 13) + ':00'],
      soil_moisture_0_to_1cm: [0], soil_temperature_0cm: [0] },
  }));
  assert.equal(status, 200);
  assert.equal(body.soilMoistureM3M3, 0);
  assert.equal(body.surfaceTempC, 0);
});

test('null and stale soil values are unavailable', async () => {
  for (const [time, moisture] of [[new Date().toISOString().slice(0,16), null], ['2000-01-01T00:00', .2]]) {
    const { status } = await callRoute('src/app/api/satellite-soil-moisture/route.ts', () => ({
      hourly: { time: [time], soil_moisture_0_to_1cm: [moisture], soil_temperature_0cm: [30] },
    }));
    assert.equal(status, 502);
  }
});

const cropData = load('src/data/togoData.ts');
const engine = load('src/lib/simulationEngine.ts', { '@/data/togoData': cropData });
test('incomplete rain evidence cannot penalize the rotation; complete drought can', () => {
  const sequence = ['Maïs', 'Soja Biologique', 'Sorgho'];
  const run = summary => engine.CropRotationEngine.simulateRotation(sequence, 'Savanes', 50, summary);
  const baseline = run();
  assert.deepEqual(run({ maxDrySpellDays: 15, validRainDaysCount: 20, periodDays: 30 }), baseline);
  assert.ok(run({ maxDrySpellDays: 15, validRainDaysCount: 30, periodDays: 30 }).resilienceScore < baseline.resilienceScore);
});
test('scenario fingerprint includes temperature, duration and capital', () => {
  const run = (...args) => engine.ParametricInsuranceEngine.evaluateClaimTrigger(...args);
  const base = run(-10, 1, 3, 100000);
  assert.equal(base.auditFingerprint, run(-10, 1, 3, 100000).auditFingerprint);
  for (const other of [run(-10, 2, 3, 100000), run(-10, 1, 4, 100000), run(-10, 1, 3, 200000)]) {
    assert.notEqual(base.auditFingerprint, other.auditFingerprint);
  }
  assert.equal(base.sha256Hash, undefined);
});

test('chart has gaps, no invented temperatures and actual coverage', () => {
  const React = require('react');
  const Chart = load('src/components/ClimateChart.tsx').ClimateChart;
  const series = [28, null, 30].map((tempMean, i) => ({ dateIso: `2026-01-0${i+1}`,
    tempMean, tempMin: null, tempMax: null, rainMm: null, solarRadiation: null, hasMissingData: true }));
  const html = require('react-dom/server').renderToStaticMarkup(React.createElement(Chart, {
    regionName: 'Savanes', onRetry: () => {}, weather: { status: 'ready', data: {
      series, periodDays: 3, validDaysCount: 0, missingDaysCount: 3,
      summary: { totalRainMm: null, maxDrySpellDays: null, validRainDaysCount: 0, periodDays: 3 },
    } },
  }));
  assert.equal((html.match(/data-kind="temperature"/g) || []).length, 2);
  const line = html.match(/data-kind="temperature-line" d="([^"]*)"/)[1];
  assert.equal((line.match(/M /g) || []).length, 2);
  assert.ok(!line.includes('L '));
  assert.ok(html.includes('Données partielles'));
  assert.ok(!html.includes('31 j'));
});

// Deterministic hook scheduler: exercises effects and cleanup, including a render
// before the next effects and providers that ignore AbortSignal.
function hooks() {
  const React = require('react');
  let values = [], effects = [], index = 0, pending = [];
  return {
    react: { ...React,
      useState(initial) { const k = index++; if (!(k in values)) values[k] = typeof initial === 'function' ? initial() : initial;
        return [values[k], next => { values[k] = typeof next === 'function' ? next(values[k]) : next; }]; },
      useEffect(callback, deps) { const k = index++;
        if (!effects[k] || deps.some((d, i) => d !== effects[k].deps[i])) {
          effects[k]?.cleanup?.(); effects[k] = { deps };
          pending.push(() => { effects[k].cleanup = callback(); });
        }
      },
    },
    render(callback) { index = 0; const result = callback(); const work = pending; pending = []; work.forEach(f => f()); return result; },
    cleanup() { effects.forEach(effect => effect?.cleanup?.()); },
  };
}
const tick = () => new Promise(resolve => setImmediate(resolve));
test('both sources load immediately; failed region change and late replies cannot reuse old data', async () => {
  const h = hooks(), original = global.fetch, requests = [];
  global.fetch = (url, options) => new Promise(resolve => requests.push({ url, options, resolve }));
  try {
    const { useRegionalEnvironment } = load('src/lib/useRegionalEnvironment.ts', { react: h.react });
    let lat = 10.8;
    const render = () => h.render(() => useRegionalEnvironment(lat, .2));
    render();
    assert.equal(requests.length, 2);
    requests[0].resolve({ ok: true, json: async () => ({ summary: { maxDrySpellDays: 15 } }) });
    await tick();
    assert.equal(render().weather.status, 'ready');
    lat = 9.5;
    const switched = render();
    assert.equal(switched.weather.status, 'loading');
    assert.equal(switched.weather.data, undefined);
    assert.ok(requests[0].options.signal.aborted);
    requests[1].resolve({ ok: true, json: async () => ({ soilMoistureM3M3: .3 }) });
    requests[2].resolve({ ok: false, json: async () => ({ error: 'offline' }) });
    requests[3].resolve({ ok: false, json: async () => ({ error: 'offline' }) });
    await tick();
    const failed = render();
    assert.equal(failed.weather.status, 'error');
    assert.equal(failed.soil.status, 'error');
    assert.equal(failed.soil.data, undefined);
    failed.retry();
    assert.equal(render().weather.status, 'loading');
    assert.equal(requests.length, 6);
  } finally { h.cleanup(); global.fetch = original; }
});

function findElement(tree, predicate) {
  if (Array.isArray(tree)) {
    for (const child of tree) { const found = findElement(child, predicate); if (found) return found; }
  } else if (tree && typeof tree === 'object') {
    if (predicate(tree)) return tree;
    return findElement(tree.props?.children, predicate);
  }
}
function elementText(tree) {
  if (typeof tree === 'string') return tree;
  if (Array.isArray(tree)) return tree.map(elementText).join('');
  return tree && typeof tree === 'object' ? elementText(tree.props?.children) : '';
}
test('page keeps manual soil edits across tabs and clears them on region change', async () => {
  const h = hooks(), original = global.fetch;
  const aliases = { react: h.react, '@/data/togoData': cropData, '@/lib/simulationEngine': engine,
    'lucide-react': await import('lucide-react') };
  aliases['@/lib/useRegionalEnvironment'] = load('src/lib/useRegionalEnvironment.ts', { react: h.react });
  const components = {};
  for (const name of ['Header','VisualMetrics','RotationSimulator','DownscalingPanel','InstitutionalTab','RuralInclusionTab','ClimateChart','FieldLocationSelector']) {
    components[name] = () => null;
    aliases['@/components/' + name] = { [name]: components[name] };
  }
  const urls = [];
  global.fetch = async url => { urls.push(url); return { ok: false, json: async () => ({ error: 'offline' }) }; };
  try {
    const Page = load('src/app/page.tsx', aliases).default;
    const render = () => h.render(Page);
    let tree = render();
    assert.equal(urls.length, 2);
    assert.equal(findElement(tree, e => e.type === components.VisualMetrics), undefined);
    await tick(); tree = render();
    assert.equal(findElement(tree, e => e.type === components.VisualMetrics), undefined);
    findElement(tree, e => e.type === 'button' && elementText(e).includes('Activer un scénario manuel')).props.onClick();
    tree = render();
    assert.ok(findElement(tree, e => e.type === components.VisualMetrics));
    const clickTab = label => {
      findElement(tree, e => e.type === 'button' && elementText(e).includes(label)).props.onClick();
      tree = render();
    };
    clickTab('Estimation du sol');
    const edited = { moisture: .25, temperature: 32, ndvi: .65 };
    findElement(tree, e => e.type === components.DownscalingPanel).props.onChange(edited);
    tree = render();
    clickTab('Plan de Culture'); clickTab('Estimation du sol');
    const panel = findElement(tree, e => e.type === components.DownscalingPanel);
    assert.deepEqual(panel.props.inputs, edited);
    assert.equal(panel.props.manual, true);
    assert.equal(urls.length, 2); // Navigation does not refetch or reset inputs.
    findElement(tree, e => e.type === components.Header).props.onSelectRegion('Kara');
    tree = render();
    assert.equal(findElement(tree, e => e.type === components.VisualMetrics), undefined);
    assert.equal(findElement(tree, e => e.type === components.DownscalingPanel).props.manual, false);
  } finally { h.cleanup(); global.fetch = original; }
});

test('hydric yield follows the stated linear Ky relation without a hidden 25 percent floor', () => {
  const result = engine.CropRotationEngine.simulateRotation(['Maïs'], 'Savanes', 0);
  const cycle = result.detailsCycles[0];
  const expected = cropData.CROP_DATABASE['Maïs'].rendementMoyenTHa *
    Math.max(0, 1 - cycle.risqueStressPct / 100) * 1000 * 250;
  assert.ok(Math.abs(cycle.revenuEstimeFcfa - expected) < 500);
});

test('water is conserved between cycles, including exhausted soil', () => {
  const result = engine.CropRotationEngine.simulateRotation(['Maïs','Maïs'], 'Savanes', 0,
    undefined, undefined, { rainfallMmPerDay: 0 });
  for (const cycle of result.detailsCycles) {
    assert.equal(cycle.initialWaterMm, 0);
    assert.equal(cycle.residualWaterMm, 0);
    assert.equal(cycle.revenuEstimeFcfa, 0);
  }
});

test('all score components share a 0-100 scale and sum to the reported score', () => {
  const r = engine.CropRotationEngine.simulateRotation(['Maïs','Soja Biologique','Sorgho'], 'Savanes', 55);
  assert.equal(r.scoreComponents.diversity, 100);
  const s = r.scoreComponents;
  assert.ok(Math.abs(r.resilienceScore - (s.water*.4+s.nitrogen*.25+s.erosion*.15+s.diversity*.2)) <= .1);
});

test('active recommendation and main scenario have identical drought context and results', () => {
  const h = hooks(), calls = [];
  const context = { regionName: 'Savanes', pawPercent: 55,
    weatherObservation: { maxDrySpellDays: 20, validRainDaysCount: 30, periodDays: 30 },
    customPrices: { 'Maïs': 500 }, rainfallMmPerDay: 2, slopeDeg: 2.1 };
  const seq = ['Maïs','Soja Biologique','Sorgho'];
  const main = engine.CropRotationEngine.simulateRotation(seq, context.regionName, context.pawPercent,
    context.weatherObservation, context.customPrices, context);
  const wrapped = { ...engine, CropRotationEngine: { ...engine.CropRotationEngine,
    simulateRotation: (...args) => { const r=engine.CropRotationEngine.simulateRotation(...args); calls.push(r); return r; } } };
  const Component = load('src/components/RotationSimulator.tsx', {
    react: h.react, '@/data/togoData': cropData, '@/lib/simulationEngine': wrapped,
  }).RotationSimulator;
  h.render(() => Component({ cropSequence: seq, simResult: main, regionName:'Savanes', pawPercent:55,
    context, customPrices:context.customPrices, viewMode:'expert', onChangeCrop:()=>{}, onApplyPreset:()=>{} }));
  const same = calls.find(r=>r.sequence===main.sequence);
  assert.ok(same);
  assert.deepEqual(same, main);
});
