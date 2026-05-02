import { chromium } from "playwright"
import { createServer } from "vite"
import { mkdir, readdir, rename, rm, writeFile } from "node:fs/promises"
import path from "node:path"
import process from "node:process"

const deckRoot = process.cwd()
const outputRoot = path.resolve(deckRoot, "..", "slides as images")
const latestDir = path.join(outputRoot, "latest")
const archiveDir = path.join(outputRoot, "archive")
const viewport = { width: 1920, height: 1080 }
const commandUsed = "npm run export:images"

function timestampForPath(date = new Date()) {
  const pad = (value) => String(value).padStart(2, "0")
  return [
    date.getFullYear(),
    pad(date.getMonth() + 1),
    pad(date.getDate()),
  ].join("-") + `_${pad(date.getHours())}-${pad(date.getMinutes())}-${pad(date.getSeconds())}`
}

async function directoryHasFiles(dir) {
  try {
    return (await readdir(dir)).length > 0
  } catch (error) {
    if (error?.code === "ENOENT") return false
    throw error
  }
}

async function rotateLatest(timestamp) {
  await mkdir(outputRoot, { recursive: true })
  await mkdir(archiveDir, { recursive: true })

  if (await directoryHasFiles(latestDir)) {
    await mkdir(archiveDir, { recursive: true })
    await rename(latestDir, path.join(archiveDir, timestamp))
    return true
  }

  await rm(latestDir, { recursive: true, force: true })
  return false
}

async function waitForDeck(page) {
  await page.waitForSelector(".reveal .slides section", { timeout: 30_000 })
  await page.waitForFunction(() => document.querySelector(".reveal.ready, .reveal") !== null, null, { timeout: 30_000 })
  await page.evaluate(() => document.fonts?.ready)
  await page.waitForTimeout(750)
}

async function slideCount(page) {
  return page.locator(".reveal .slides > section").count()
}

async function showSlide(page, index) {
  await page.evaluate((slideIndex) => {
    window.location.hash = `/${slideIndex}`
  }, index)

  await page.waitForFunction(
    (slideIndex) => {
      const sections = Array.from(document.querySelectorAll(".reveal .slides > section"))
      return sections[slideIndex]?.classList.contains("present")
    },
    index,
    { timeout: 10_000 },
  )

  await page.evaluate(() => document.fonts?.ready)
  await page.waitForTimeout(500)
}

async function main() {
  const timestamp = timestampForPath()
  const archivedPreviousLatest = await rotateLatest(timestamp)
  await mkdir(latestDir, { recursive: true })

  const server = await createServer({
    root: deckRoot,
    logLevel: "error",
    server: {
      host: "127.0.0.1",
      port: 4173,
      strictPort: false,
    },
  })

  let browser

  try {
    await server.listen()
    const serverUrls = server.resolvedUrls?.local ?? []
    const deckUrl = serverUrls.find((url) => url.startsWith("http://127.0.0.1")) ?? serverUrls[0]

    if (!deckUrl) {
      throw new Error("Vite dev server started, but no local URL was reported.")
    }

    browser = await chromium.launch()
    const page = await browser.newPage({ viewport, deviceScaleFactor: 1 })

    await page.goto(deckUrl, { waitUntil: "networkidle", timeout: 30_000 })
    await waitForDeck(page)

    await page.addStyleTag({
      content: `
        .reveal .controls,
        .reveal .progress,
        .reveal .slide-number,
        .reveal aside.notes {
          display: none !important;
        }

        .reveal .fragment {
          opacity: 1 !important;
          visibility: visible !important;
          transform: none !important;
        }

        .reveal * {
          transition: none !important;
          animation-duration: 0s !important;
          animation-delay: 0s !important;
        }
      `,
    })

    const count = await slideCount(page)

    if (count === 0) {
      throw new Error("No slides found at .reveal .slides > section.")
    }

    for (let index = 0; index < count; index += 1) {
      await showSlide(page, index)
      const fileName = `slide-${String(index + 1).padStart(2, "0")}.png`
      await page.screenshot({
        path: path.join(latestDir, fileName),
        fullPage: false,
        animations: "disabled",
      })
    }

    const files = await readdir(latestDir)
    const pngFiles = files.filter((file) => file.endsWith(".png")).sort()

    if (pngFiles.length !== count) {
      throw new Error(`Expected ${count} slide PNGs, found ${pngFiles.length}.`)
    }

    const manifest = {
      exportTimestamp: new Date().toISOString(),
      deckPath: deckRoot,
      deckUrl,
      slideCount: count,
      imageSize: viewport,
      commandUsed,
      fragmentsCapturedAsFinalState: true,
      outputDirectory: latestDir,
      archivedPreviousLatest,
      slides: pngFiles,
    }

    await writeFile(path.join(latestDir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8")

    console.log(`Exported ${count} slides to ${latestDir}`)
    console.log(`Previous latest archived: ${archivedPreviousLatest ? "yes" : "no"}`)
  } finally {
    await browser?.close()
    await server.close()
  }
}

main().catch((error) => {
  console.error("Slide image export failed.")
  console.error(error)
  process.exitCode = 1
})
