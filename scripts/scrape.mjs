import { writeFileSync, readFileSync, mkdirSync, existsSync } from 'fs';

const PAGE_URL = 'https://www.figcvenetocalcio.it/pagina-resp.aspx?PId=27987';
const BASE_URL = 'https://www.figcvenetocalcio.it';
const DATA_PATH = 'docs/data.json';

async function main() {
    const res = await fetch(PAGE_URL, {
        headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' }
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const html = await res.text();

    const viewPaths = {};
    const downloadPaths = {};

    const linkRegex = /href="(\/download\.ashx\?act=(download|vis)&(?:amp;)?file=([^"]*?Com_(\d+)\.pdf[^"]*))/g;
    let match;

    while ((match = linkRegex.exec(html)) !== null) {
        const path = match[1].replace(/&amp;/g, '&');
        const action = match[2];
        const num = parseInt(match[4]);
        if (action === 'vis') viewPaths[num] = path;
        else downloadPaths[num] = path;
    }

    const allNums = [...new Set([
        ...Object.keys(viewPaths),
        ...Object.keys(downloadPaths)
    ].map(Number))];

    const comunicati = allNums.map(num => {
        const vp = viewPaths[num] || downloadPaths[num] || '';
        const dp = downloadPaths[num] || viewPaths[num] || '';

        const dateMatch = html.match(
            new RegExp(`(\\d{2}/\\d{2}/\\d{2})[\\s\\S]{0,500}?Com_${num}\\.pdf`)
        );

        return {
            number: num,
            title: `Comunicato ${num}`,
            date: dateMatch ? dateMatch[1] : '',
            viewURL: `${BASE_URL}${vp}`,
            downloadURL: `${BASE_URL}${dp}`
        };
    });

    comunicati.sort((a, b) => b.number - a.number);

    // Detect new comunicati by comparing with existing data
    let newComunicati = [];
    if (existsSync(DATA_PATH)) {
        try {
            const existing = JSON.parse(readFileSync(DATA_PATH, 'utf-8'));
            const existingNums = new Set(existing.comunicati.map(c => c.number));
            newComunicati = comunicati.filter(c => !existingNums.has(c.number));
        } catch {
            // First run or corrupted file, no notifications
        }
    }

    mkdirSync('docs', { recursive: true });
    writeFileSync(DATA_PATH, JSON.stringify({
        lastUpdate: new Date().toISOString(),
        comunicati
    }, null, 2));

    console.log(`Trovati ${comunicati.length} comunicati`);

    if (newComunicati.length > 0) {
        const names = newComunicati.map(c => c.title).join(', ');
        console.log(`NUOVI: ${names}`);
        // Write new comunicati info for the workflow notification step
        writeFileSync('new_comunicati.txt', names);
    }
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});
