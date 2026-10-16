#!/usr/bin/env node

/**
 * sync-catalogs.js — Unified Catalog synchronization utility for TelcoChiselOS
 *
 * Canonical Source of Truth: data/tools.json
 * Generated targets:
 *   - docs/data/tools.js       (mirror for parity; live site is TelcoChisel/website)
 *   - builder/docs/app.js      (In-ISO offline documentation portal, Vanilla JS)
 *
 * The Nuxt portal is https://github.com/TelcoChisel/website — it pulls this
 * SoT on deploy. Keep docs/data/tools.js in sync so CI can still detect drift.
 *
 * Usage:
 *   node scripts/sync-catalogs.js          # Check for catalog drift across all surfaces
 *   node scripts/sync-catalogs.js --build  # Generate docs/data/tools.js and builder/docs/app.js from data/tools.json
 *   node scripts/sync-catalogs.js --sync   # Alias for --build
 */

const fs = require('fs');
const path = require('path');

const CANONICAL_DATA_PATH = path.join(__dirname, '..', 'data', 'tools.json');
const ONLINE_CATALOG_PATH = path.join(__dirname, '..', 'docs', 'data', 'tools.js');
const OFFLINE_APP_PATH = path.join(__dirname, '..', 'builder', 'docs', 'app.js');

function loadCanonicalCatalog() {
    if (!fs.existsSync(CANONICAL_DATA_PATH)) {
        throw new Error(`Canonical data file not found at ${CANONICAL_DATA_PATH}`);
    }
    const raw = fs.readFileSync(CANONICAL_DATA_PATH, 'utf8');
    return JSON.parse(raw);
}

function parseOnlineCatalog() {
    if (!fs.existsSync(ONLINE_CATALOG_PATH)) {
        throw new Error(`Online catalog file not found at ${ONLINE_CATALOG_PATH}`);
    }
    const content = fs.readFileSync(ONLINE_CATALOG_PATH, 'utf8');
    const match = content.match(/export\s+const\s+toolsCatalog\s*=\s*(\[\s*[\s\S]*?\]);?\s*$/);
    if (!match) {
        throw new Error(`Failed to parse online catalog at ${ONLINE_CATALOG_PATH}`);
    }
    const arrayStr = match[1];
    return Function(`"use strict"; return (${arrayStr});`)();
}

function parseOfflineCatalog() {
    if (!fs.existsSync(OFFLINE_APP_PATH)) {
        throw new Error(`Offline app file not found at ${OFFLINE_APP_PATH}`);
    }
    const content = fs.readFileSync(OFFLINE_APP_PATH, 'utf8');
    const match = content.match(/const\s+toolsCatalog\s*=\s*(\[\s*[\s\S]*?\]);\s*document\.addEventListener/);
    if (!match) {
        throw new Error(`Failed to parse offline catalog at ${OFFLINE_APP_PATH}`);
    }
    const arrayStr = match[1];
    const catalog = Function(`"use strict"; return (${arrayStr});`)();
    return { catalog, fullContent: content };
}

function generateOnlineFile(catalog) {
    const items = catalog.map(tool => {
        const obj = {
            name: tool.name,
            slug: tool.slug || tool.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, ''),
            category: tool.category,
            status: tool.status,
            desc: tool.desc,
            path: tool.path,
            cmd: tool.cmd
        };
        const lines = Object.entries(obj).map(([k, v]) => `        ${k}: ${JSON.stringify(v)}`);
        return `    {\n${lines.join(',\n')}\n    }`;
    });

    return `export const toolsCatalog = [\n${items.join(',\n')}\n];\n`;
}

function generateOfflineArray(catalog) {
    const items = catalog.map(tool => {
        const obj = {
            name: tool.name,
            category: tool.category,
            status: tool.status,
            desc: tool.desc,
            path: tool.path,
            cmd: tool.cmd
        };
        return "    " + JSON.stringify(obj, null, 8).replace(/\n/g, "\n    ");
    });

    return `const toolsCatalog = [\n${items.join(',\n')}\n];`;
}

function compareCatalogs(sourceName, sourceList, targetName, targetList) {
    const differences = [];

    if (sourceList.length !== targetList.length) {
        differences.push(`Count mismatch: ${sourceName} has ${sourceList.length} items, ${targetName} has ${targetList.length} items.`);
    }

    const maxLen = Math.max(sourceList.length, targetList.length);
    for (let i = 0; i < maxLen; i++) {
        const src = sourceList[i];
        const tgt = targetList[i];

        if (!src) {
            differences.push(`Item #${i + 1}: Missing in ${sourceName} (${tgt.name})`);
            continue;
        }
        if (!tgt) {
            differences.push(`Item #${i + 1}: Missing in ${targetName} (${src.name})`);
            continue;
        }

        const fields = ['name', 'category', 'status', 'desc', 'path', 'cmd'];
        for (const field of fields) {
            if (src[field] !== tgt[field]) {
                differences.push(`Item #${i + 1} (${src.name}) field '${field}' mismatch:\n  ${sourceName}: ${JSON.stringify(src[field])}\n  ${targetName}: ${JSON.stringify(tgt[field])}`);
            }
        }
    }

    return differences;
}

function buildTargets(canonical) {
    console.log(`Building catalog targets from ${CANONICAL_DATA_PATH} (${canonical.length} tools)...`);

    // 1. Write docs/data/tools.js
    const onlineCode = generateOnlineFile(canonical);
    fs.writeFileSync(ONLINE_CATALOG_PATH, onlineCode, 'utf8');
    console.log(`  ✓ Updated ${path.relative(process.cwd(), ONLINE_CATALOG_PATH)}`);

    // 2. Write builder/docs/app.js
    const { fullContent } = parseOfflineCatalog();
    const offlineArrayCode = generateOfflineArray(canonical);
    const updatedContent = fullContent.replace(
        /const\s+toolsCatalog\s*=\s*\[\s*[\s\S]*?\];\s*document\.addEventListener/,
        `${offlineArrayCode}\n\ndocument.addEventListener`
    );
    fs.writeFileSync(OFFLINE_APP_PATH, updatedContent, 'utf8');
    console.log(`  ✓ Updated ${path.relative(process.cwd(), OFFLINE_APP_PATH)}`);

    console.log(`SUCCESS: All catalog surfaces synchronized with ${canonical.length} tools!`);
}

function main() {
    const isBuild = process.argv.includes('--build') || process.argv.includes('--sync');
    console.log('=== TelcoChisel Unified Catalog Management ===');

    try {
        const canonical = loadCanonicalCatalog();

        if (isBuild) {
            buildTargets(canonical);
            process.exit(0);
        }

        const online = parseOnlineCatalog();
        const { catalog: offline } = parseOfflineCatalog();

        console.log(`Canonical (data/tools.json)  : ${canonical.length} tools`);
        console.log(`Online (docs/data/tools.js)  : ${online.length} tools`);
        console.log(`Offline (builder/docs/app.js): ${offline.length} tools\n`);

        const diffsOnline = compareCatalogs('Canonical', canonical, 'Online', online);
        const diffsOffline = compareCatalogs('Canonical', canonical, 'Offline', offline);

        const allDiffs = [...diffsOnline, ...diffsOffline];

        if (allDiffs.length === 0) {
            console.log('SUCCESS: All catalog files are in 100% parity across all platforms!');
            process.exit(0);
        }

        console.warn(`WARNING: Detected ${allDiffs.length} difference(s) across catalog targets:`);
        allDiffs.forEach(d => console.warn(` - ${d}`));
        console.log('\nRun `node scripts/sync-catalogs.js --build` to regenerate targets from data/tools.json.');
        process.exit(1);
    } catch (err) {
        console.error(`ERROR: ${err.message}`);
        process.exit(1);
    }
}

main();
