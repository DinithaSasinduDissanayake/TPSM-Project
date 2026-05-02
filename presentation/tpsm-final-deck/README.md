# TPSM Final Presentation Deck

Fresh browser presentation app for the TPSM final group assignment.

Stack:

- Vite
- React
- TypeScript
- reveal.js
- Tailwind CSS
- real shadcn/ui components
- Recharts

## Run

```bash
npm install
npm run dev -- --host 127.0.0.1
```

Open:

```text
http://127.0.0.1:5173/
```

## Speaker View

Open the deck in a browser and press `S`.

Speaker notes are written with reveal.js:

```tsx
<aside className="notes">...</aside>
```

## Build

```bash
npm run lint
npm run build
```

## Export Slide Images

```bash
npm run export:images
```

The export script starts a local Vite server, captures one final-state PNG per slide at 1920 × 1080, and writes the images to:

```text
../slides as images/latest/
```

If a previous `latest/` export exists, it is moved to `../slides as images/archive/<timestamp>/` before the new export is created.
The script also writes a `manifest.json` with slide count, image size, command, deck path, and fragment handling details. Archives are
not deleted automatically.

## Notes

- This is a first review draft.
- Group member names, student IDs, and contribution split are intentionally not included.
- Selected analysis plots are copied into `public/analysis-plots/`.
