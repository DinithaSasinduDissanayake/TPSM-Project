import { useEffect } from "react"
import Reveal from "reveal.js"
import Notes from "reveal.js/plugin/notes"
import "reveal.js/reveal.css"
import {
  Bar,
  BarChart,
  CartesianGrid,
  LabelList,
  ReferenceLine,
  XAxis,
  YAxis,
} from "recharts"
import { SlideShell } from "@/components/deck/SlideShell"
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import {
  classificationPairs,
  descriptiveCounts,
  finalNumbers,
  headlineComparison,
  metricWinRates,
  modelPairRates,
  readinessRows,
  regressionPairs,
  taskWinRates,
} from "@/data/analysis"

type ModelPairRow = {
  single: string
  ensemble: string
  rationale: string
}

const rateConfig = {
  value: { label: "Win rate", color: "var(--chart-3)" },
} satisfies ChartConfig

function NotesBlock({ children }: { children: string }) {
  return <aside className="notes">{children}</aside>
}

function BigNumber({
  label,
  value,
  detail,
  compact = false,
}: {
  label: string
  value: string
  detail?: string
  compact?: boolean
}) {
  return (
    <div className="flex min-w-0 flex-col gap-1.5">
      <p className="text-sm text-muted-foreground md:text-base">{label}</p>
      <p
        className={
          compact
            ? "text-3xl font-semibold leading-none tracking-tight text-foreground md:text-4xl lg:text-5xl"
            : "text-5xl font-semibold leading-none tracking-tight text-foreground md:text-6xl lg:text-7xl"
        }
      >
        {value}
      </p>
      {detail ? <p className="max-w-md text-base leading-snug text-muted-foreground md:text-lg">{detail}</p> : null}
    </div>
  )
}

function Statement({ children }: { children: string }) {
  return <p className="max-w-[58rem] text-3xl font-medium leading-tight text-foreground md:text-4xl">{children}</p>
}

function SimpleBars({
  data,
  height = 340,
  percent = false,
}: {
  data: Array<{ name: string; value: number }>
  height?: number
  percent?: boolean
}) {
  return (
    <ChartContainer config={rateConfig} className="w-full" style={{ height }}>
      <BarChart data={data} margin={{ top: 24, right: 28, left: 8, bottom: 18 }}>
        <CartesianGrid vertical={false} />
        <XAxis dataKey="name" tickMargin={10} />
        <YAxis domain={percent ? [0, 100] : undefined} tickFormatter={(value) => (percent ? `${value}%` : `${value}`)} />
        {percent ? <ReferenceLine y={50} stroke="var(--muted-foreground)" strokeDasharray="5 5" /> : null}
        <ChartTooltip content={<ChartTooltipContent />} />
        <Bar dataKey="value" fill="var(--color-value)" radius={[5, 5, 0, 0]}>
          <LabelList
            dataKey="value"
            position="top"
            formatter={(value: unknown) => {
              const numericValue = Number(value)
              return percent ? `${numericValue.toFixed(1)}%` : numericValue.toLocaleString()
            }}
            className="fill-foreground text-sm font-medium"
          />
        </Bar>
      </BarChart>
    </ChartContainer>
  )
}

function HorizontalRates({ data, chartHeight = 390 }: { data: Array<{ name: string; value: number }>; chartHeight?: number }) {
  return (
    <ChartContainer config={rateConfig} className="w-full" style={{ height: chartHeight }}>
      <BarChart data={data} layout="vertical" margin={{ top: 8, right: 52, left: 8, bottom: 8 }}>
        <CartesianGrid horizontal={false} />
        <XAxis type="number" domain={[0, 100]} tickFormatter={(value) => `${value}%`} />
        <YAxis dataKey="name" type="category" className="text-xs md:text-sm" width={220} tickMargin={8} />
        <ReferenceLine x={50} stroke="var(--muted-foreground)" strokeDasharray="5 5" />
        <ChartTooltip content={<ChartTooltipContent />} />
        <Bar dataKey="value" fill="var(--color-value)" radius={[0, 5, 5, 0]}>
          <LabelList
            dataKey="value"
            position="right"
            formatter={(value: unknown) => `${Number(value).toFixed(1)}%`}
            className="fill-foreground text-xs font-medium md:text-sm"
          />
        </Bar>
      </BarChart>
    </ChartContainer>
  )
}

function Divider() {
  return <div className="my-6 h-px w-full bg-border" aria-hidden />
}

function PairList({
  title,
  caption,
  pairs,
}: {
  title: string
  caption: string
  pairs: ReadonlyArray<ModelPairRow>
}) {
  return (
    <div className="flex min-w-0 flex-col gap-3 rounded-xl border border-border bg-muted/15 p-5 md:p-6">
      <div>
        <p className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">{title}</p>
        <p className="mt-1 text-sm leading-snug text-muted-foreground md:text-base">{caption}</p>
      </div>
      <ul className="space-y-2.5">
        {pairs.map((p) => (
          <li key={`${p.single}-${p.ensemble}`} className="flex flex-col gap-0.5">
            <span className="text-base leading-tight md:text-lg">
              <span className="font-medium text-foreground">{p.single}</span>
              <span className="px-2 text-muted-foreground">vs</span>
              <span className="font-medium text-foreground">{p.ensemble}</span>
            </span>
            <span className="text-xs leading-snug text-muted-foreground md:text-sm">{p.rationale}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}

/** Tiny inline diagram of k-fold cross-validation with a "× repeats" indicator beside it. */
function FoldsDiagram() {
  const folds = [0, 1, 2, 3, 4]
  return (
    <div className="flex flex-col gap-3" aria-label="Five-fold cross-validation diagram with repeats indicator">
      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground md:text-sm">
        <span className="flex items-center gap-1.5">
          <span className="inline-block h-3 w-3 rounded-sm border border-border bg-muted" /> train
        </span>
        <span className="flex items-center gap-1.5">
          <span className="inline-block h-3 w-3 rounded-sm border border-primary bg-primary/70" /> test
        </span>
      </div>
      <div className="flex items-stretch gap-3">
        <div className="flex flex-1 flex-col gap-1.5">
          {folds.map((row) => (
            <div key={row} className="flex items-center gap-2">
              <span className="w-12 shrink-0 text-xs text-muted-foreground md:text-sm">Fold {row + 1}</span>
              <div className="flex flex-1 gap-1">
                {folds.map((col) => (
                  <div
                    key={col}
                    className={
                      "h-5 flex-1 rounded-sm border md:h-6 " +
                      (col === row ? "border-primary bg-primary/70" : "border-border bg-muted")
                    }
                  />
                ))}
              </div>
            </div>
          ))}
        </div>
        <div className="flex flex-col items-center justify-center rounded-lg border border-dashed border-primary/40 bg-primary/5 px-3 py-2 text-center">
          <span className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">× repeats</span>
          <span className="mt-1 text-3xl font-light leading-none text-primary md:text-4xl">↻</span>
          <span className="mt-1 max-w-[7rem] text-[0.65rem] leading-snug text-muted-foreground md:text-xs">
            reshuffle, run all folds again
          </span>
        </div>
      </div>
      <p className="text-xs leading-snug text-muted-foreground md:text-sm">
        Each fold yields one comparison row per metric; repeats reshuffle and do it all again, so the table accumulates many
        comparison rows per pair × dataset.
      </p>
    </div>
  )
}

/** Visual recipe for one paired comparison row. */
function PairedRowSchematic() {
  return (
    <div
      className="flex flex-col gap-3 rounded-xl border border-border bg-muted/15 p-5 md:p-6"
      aria-label="Paired comparison row schematic"
    >
      <p className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">How one row resolves</p>

      <div className="rounded-lg border border-border bg-background/60 px-4 py-3">
        <p className="text-[0.65rem] font-semibold uppercase tracking-wide text-muted-foreground md:text-xs">Shared context</p>
        <p className="mt-1 text-sm leading-snug text-foreground md:text-base">
          dataset · split · pair · metric
        </p>
      </div>

      <div className="flex justify-center text-2xl leading-none text-muted-foreground" aria-hidden>
        ↓
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="rounded-lg border border-border px-3 py-2.5">
          <p className="text-[0.65rem] font-semibold uppercase tracking-wide text-muted-foreground md:text-xs">Single model</p>
          <p className="mt-1 font-mono text-base leading-tight text-foreground md:text-lg">score<sub>S</sub></p>
        </div>
        <div className="rounded-lg border border-primary/40 bg-primary/5 px-3 py-2.5">
          <p className="text-[0.65rem] font-semibold uppercase tracking-wide text-primary md:text-xs">Ensemble model</p>
          <p className="mt-1 font-mono text-base leading-tight text-foreground md:text-lg">score<sub>E</sub></p>
        </div>
      </div>

      <div className="flex justify-center text-2xl leading-none text-muted-foreground" aria-hidden>
        ↓
      </div>

      <div className="rounded-lg border border-border bg-background/60 px-4 py-3">
        <p className="text-[0.65rem] font-semibold uppercase tracking-wide text-muted-foreground md:text-xs">
          Difference value (sign chooses the winner)
        </p>
        <p className="mt-1 font-mono text-sm leading-snug text-foreground md:text-base">
          difference = score<sub>E</sub> − score<sub>S</sub>{" "}
          <span className="text-muted-foreground">(direction-adjusted per metric)</span>
        </p>
        <ul className="mt-2 space-y-1 text-sm leading-snug md:text-base">
          <li>
            <span className="font-semibold text-emerald-700 dark:text-emerald-400">+</span>
            <span className="text-muted-foreground"> ensemble wins</span>
          </li>
          <li>
            <span className="font-semibold text-amber-800 dark:text-amber-300">−</span>
            <span className="text-muted-foreground"> single model wins</span>
          </li>
          <li>
            <span className="font-semibold text-foreground">0</span>
            <span className="text-muted-foreground"> tie</span>
          </li>
        </ul>
      </div>
    </div>
  )
}

function App() {
  useEffect(() => {
    const revealElement = document.querySelector(".reveal")
    if (!(revealElement instanceof HTMLElement)) return

    const deck = new Reveal(revealElement, {
      hash: true,
      controls: true,
      progress: true,
      center: false,
      transition: "fade",
      plugins: [Notes],
    })

    deck.initialize()
    return () => {
      deck.destroy()
    }
  }, [])

  return (
    <div className="reveal">
      <div className="slides">
        {/* 1 */}
        <section>
          <SlideShell
            kicker="TPSM — research question"
            title="Do ensembles outperform single models across many comparisons?"
            slideNumber={1}
            tags={["Research question"]}
          >
            <div className="flex h-full flex-col justify-center gap-8">
              <Statement>
                We stress-tested a common machine-learning claim with descriptive summaries and a formal hypothesis test.
              </Statement>
              <p className="fragment max-w-[48rem] text-xl leading-relaxed text-muted-foreground md:text-2xl">
                We focus on classification and regression tasks (time series is out of scope).
              </p>
            </div>
          </SlideShell>
          <NotesBlock>
            Open with the question, not a leaderboard. This is a course project: many paired comparisons, one clear claim. Mention
            once that the benchmark excludes time series so listeners know the boundary, without sounding defensive.
          </NotesBlock>
        </section>

        {/* 2 */}
        <section>
          <SlideShell
            kicker="The statement"
            title="What we set out to assess"
            slideNumber={2}
            concepts="Frames the claim before we build the methodology that will produce comparable evidence."
            tags={["Research question", "Operationalization"]}
          >
            <div className="flex h-full flex-col gap-8">
              <blockquote className="border-l-4 border-primary pl-6 text-2xl font-medium leading-snug text-foreground md:text-3xl">
                Ensemble models perform better than single models in many prediction tasks.
              </blockquote>

              <div className="grid gap-6 md:grid-cols-3 md:gap-8">
                <div className="fragment">
                  <p className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">Meaning of “better”</p>
                  <p className="mt-2 text-base leading-relaxed text-muted-foreground md:text-lg">
                    On a given row, the ensemble must achieve the stronger metric score when both models share the same dataset,
                    split, pairing, and metric.
                  </p>
                </div>
                <div className="fragment">
                  <p className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">Why it matters</p>
                  <p className="mt-2 text-base leading-relaxed text-muted-foreground md:text-lg">
                    Ensembles cost more to train, deploy, and explain. The claim is only useful if the gain shows up consistently,
                    not just in one favourable example.
                  </p>
                </div>
                <div className="fragment">
                  <p className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">What we will do</p>
                  <p className="mt-2 text-base leading-relaxed text-muted-foreground md:text-lg">
                    Build a comparison-rich evidence base across many tasks, summarize it, then formally test whether ensembles win
                    more than half the time.
                  </p>
                </div>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Define “better”, motivate the question with cost vs benefit, and signal the plan: methodology first, descriptive analysis
            second, hypothesis testing last. This sets up the next few slides.
          </NotesBlock>
        </section>

        {/* 3 */}
        <section>
          <SlideShell
            kicker="Motivation"
            title="Why a single headline score is a weak answer"
            slideNumber={3}
            concepts="Motivates the methodology: we need many fair, repeated comparisons before we can summarize or test anything."
            tags={["Research design"]}
          >
            <div className="flex h-full flex-col justify-center gap-6 text-2xl font-medium leading-snug text-foreground md:gap-8 md:text-3xl">
              <p className="fragment">Performance swings with the dataset you happened to choose.</p>
              <p className="fragment">One train–test split can look lucky or harsh.</p>
              <p className="fragment">One metric can look good while another tells a different story.</p>
              <Divider />
              <p className="fragment text-balance text-2xl text-muted-foreground md:text-3xl">
                A claim about “many prediction tasks” needs many fair, repeated comparisons—not one isolated accuracy number.
              </p>
            </div>
          </SlideShell>
          <NotesBlock>
            Keep this conversational. Bridge to the next slide: we built a table where each row is one fair comparison, then
                    summarized and tested the pattern.
          </NotesBlock>
        </section>

        {/* 4 */}
        <section>
          <SlideShell
            kicker="Method"
            title="How we turned the claim into something measurable"
            slideNumber={4}
            concepts="Links predictive modelling outputs to the statistical story: first describe wins, then infer a population proportion."
            tags={["Research design", "Paired comparison"]}
          >
            <div className="flex h-full flex-col justify-center gap-8">
              <p className="text-xl leading-relaxed text-muted-foreground md:text-2xl">
                Model evaluations produced the comparison data. Statistical analysis tested the overall pattern.
              </p>
              <div className="fragment grid gap-4 md:grid-cols-4 md:gap-3">
                {[
                  { step: "1", label: "Benchmark tasks", detail: "Many datasets and metrics" },
                  { step: "2", label: "Train & score", detail: "Single vs ensemble under the same setup" },
                  { step: "3", label: "One row per comparison", detail: "Same split, pair, and metric" },
                  { step: "4", label: "Summarize & test", detail: "Descriptive analysis, then hypothesis testing" },
                ].map(({ step, label, detail }) => (
                  <div key={step} className="rounded-lg border border-border bg-muted/30 px-4 py-4 md:py-5">
                    <p className="text-xs font-bold text-primary">{step}</p>
                    <p className="mt-2 text-lg font-semibold leading-tight">{label}</p>
                    <p className="mt-2 text-sm leading-snug text-muted-foreground">{detail}</p>
                  </div>
                ))}
              </div>
              <div className="fragment rounded-xl border border-primary/25 bg-primary/5 px-6 py-5 md:px-8 md:py-6">
                <p className="text-lg leading-relaxed text-foreground md:text-xl">
                  We generated a wide comparison table where{" "}
                  <span className="font-semibold">each row asks one question</span>: did the ensemble beat the single model under the
                  same dataset, split, predefined model pair, and metric?
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Avoid file paths. Stress the repeated yes/no comparison encoded in difference_value, then aggregated into win rates.
          </NotesBlock>
        </section>

        {/* 5 — Designed for breadth (NEW) */}
        <section>
          <SlideShell
            kicker="Scientific design"
            title="Designed for breadth — one statement, five axes of variation"
            slideNumber={5}
            concepts="Why this design beats a one-dataset answer: the claim is broad, so the evidence has to vary on every axis the claim touches."
            tags={["Research design", "Scientific breadth"]}
          >
            <div className="flex h-full flex-col gap-6">
              <p className="max-w-[58rem] text-base leading-relaxed text-muted-foreground md:text-lg">
                The statement covers “many prediction tasks”, so a result from one dataset, one model pair, or one metric cannot
                settle it. We deliberately varied every axis the claim touches, then aggregated.
              </p>
              <div className="grid gap-4 md:grid-cols-5 md:gap-4">
                {[
                  { k: "Datasets", v: finalNumbers.datasets, n: "Different domains and shapes" },
                  { k: "Task types", v: finalNumbers.taskTypes, n: "Classification + regression" },
                  { k: "Model pairs", v: finalNumbers.modelPairs, n: "Three per task type, fixed up front" },
                  { k: "Metrics", v: finalNumbers.metrics, n: "Each metric stresses a different failure mode" },
                  { k: "Splits", v: "Many", n: "Folds × repeats per pair × dataset" },
                ].map(({ k, v, n }) => (
                  <div key={k} className="rounded-lg border border-border bg-muted/20 px-4 py-4">
                    <p className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">{k}</p>
                    <p className="mt-1 text-3xl font-semibold leading-none text-foreground md:text-4xl">{v}</p>
                    <p className="mt-2 text-xs leading-snug text-muted-foreground md:text-sm">{n}</p>
                  </div>
                ))}
              </div>
              <div className="rounded-xl border border-primary/25 bg-primary/5 px-5 py-4 md:px-6 md:py-5">
                <p className="text-base leading-relaxed text-foreground md:text-lg">
                  Multiplied together, those axes produce <span className="font-semibold">{finalNumbers.rows}</span> paired
                  comparisons. A single dataset or single metric could mislead; a result that survives this much variation is harder
                  to dismiss.
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            This is the “why our method matches the claim” slide. Stress that the breadth is not decoration — it is what allows the
            conclusion to talk about “many prediction tasks” instead of one lucky example. Mention briefly that classification and
            regression each get their own three pairs (next slide).
          </NotesBlock>
        </section>

        {/* 6 — Model pairs split by task type */}
        <section>
          <SlideShell
            kicker="Model design"
            title="Six predefined model pairings — three per task type"
            slideNumber={6}
            concepts="Continues the methodology: same fixed pairings drive every row in the comparison table."
            tags={["Predictive modelling", "Paired comparison"]}
          >
            <div className="flex h-full flex-col gap-5">
              <p className="max-w-[58rem] text-base leading-relaxed text-muted-foreground md:text-lg">
                The same three classification pairings are applied to every classification dataset, and the same three regression
                pairings to every regression dataset. Pairings were chosen up front, so each row is a like-for-like comparison rather
                than a hand-picked win.
              </p>
              <div className="grid min-h-0 gap-5 md:grid-cols-2 md:gap-6">
                <PairList
                  title="Classification pairings"
                  caption="Same three pairs run on every classification dataset."
                  pairs={classificationPairs}
                />
                <PairList
                  title="Regression pairings"
                  caption="Same three pairs run on every regression dataset."
                  pairs={regressionPairs}
                />
              </div>
              <p className="text-sm leading-snug text-muted-foreground md:text-base">
                Why predefined pairs? Each row needs both models judged on identical inputs — same dataset, same split, same metric —
                so the ensemble vs single comparison is paired and fair, not opportunistic.
              </p>
            </div>
          </SlideShell>
          <NotesBlock>
            Make three points: (1) three classification pairs and three regression pairs, (2) every dataset of that task type runs the
            same pairs, (3) fixing pairs in advance is what makes each row a fair paired comparison instead of cherry-picking. The
            three classification + three regression pairings cover both task families inside the 19-dataset benchmark.
          </NotesBlock>
        </section>

        {/* 6 — Folds & repeats with diagram */}
        <section>
          <SlideShell
            kicker="Repeated evaluations"
            title="Why folds and repeats reduce reliance on one lucky split"
            slideNumber={7}
            concepts="Folds and repeats: each pair is re-evaluated under many split contexts so the evidence is not a single roll of the dice."
            tags={["Resampling", "Folds & repeats"]}
          >
            <div className="grid h-full items-center gap-10 lg:grid-cols-[0.9fr_1.1fr] lg:gap-14">
              <FoldsDiagram />
              <div className="space-y-4 text-base leading-relaxed text-muted-foreground md:text-lg">
                <p>
                  A single train–test split can flatter or punish either model just because of where the cut happens to land.
                </p>
                <p>
                  Cross-validation rotates the test slice across folds; <span className="font-medium text-foreground">repeats</span> rerun
                  the whole cycle with a different shuffle. Every fold of every repeat produces one new comparison row per metric.
                </p>
                <p>
                  Those rows accumulate into the 13,950-row table, so the win rate we read later reflects many split contexts — not a
                  single experiment.
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Walk through the diagram: each row is one run, the highlighted square is the test fold; rotating it gives multiple paired
            comparisons; repeats reshuffle and do it again. Stress: this is design motivation, no new statistics here.
          </NotesBlock>
        </section>

        {/* 7 — One row meaning (moved after pairs+folds) */}
        <section>
          <SlideShell
            kicker="Paired comparison"
            title="What a single row represents"
            slideNumber={8}
            concepts="Paired comparison: both models see the same context before we read off who won."
            tags={["Paired comparison", "Difference value"]}
          >
            <div className="grid h-full items-center gap-10 lg:grid-cols-[0.9fr_1.1fr] lg:gap-12">
              <div className="flex min-w-0 flex-col gap-4">
                <ul className="space-y-3 text-base leading-relaxed text-muted-foreground md:text-lg">
                  <li>One task type and one dataset</li>
                  <li>One fold of one repeat (same split context for both models)</li>
                  <li>One metric and one of the six predefined pairings</li>
                  <li>
                    A stored <span className="font-medium text-foreground">difference_value</span> captures who won on that row
                  </li>
                </ul>
                <p className="text-sm leading-relaxed text-muted-foreground md:text-base">
                  Because every row pins all four context items, the comparison is paired and fair — never an apples-to-oranges
                  match-up across different setups.
                </p>
              </div>
              <PairedRowSchematic />
            </div>
          </SlideShell>
          <NotesBlock>
            Viva point: paired means apples-to-apples within a row; not two unrelated experiments. Ties are real outcomes, counted
            and handled explicitly later.
          </NotesBlock>
        </section>

        {/* 8 — Readiness check + scale (compact numbers to avoid overlap) */}
        <section>
          <SlideShell
            kicker="Analysis readiness"
            title="The evidence base before descriptive analysis"
            slideNumber={9}
            concepts="Pre-descriptive checkpoint: how much comparison data we have, and that it is structurally clean."
            tags={["Data readiness"]}
          >
            <div className="grid h-full items-start gap-10 lg:grid-cols-[0.85fr_1.15fr] lg:gap-12">
              <div className="grid grid-cols-2 gap-x-10 gap-y-7">
                <BigNumber compact label="Paired rows" value={finalNumbers.rows} />
                <BigNumber compact label="Datasets" value={finalNumbers.datasets} />
                <BigNumber compact label="Metrics" value={finalNumbers.metrics} />
                <BigNumber compact label="Model pairs" value={finalNumbers.modelPairs} />
              </div>
              <div>
                <p className="mb-3 text-sm font-semibold uppercase tracking-wide text-primary">Readiness checks</p>
                <Table>
                  <TableHeader>
                    <TableRow className="hover:bg-transparent">
                      <TableHead className="text-base font-semibold">Check</TableHead>
                      <TableHead className="text-base font-semibold">Outcome</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {readinessRows.map(([check, result]) => (
                      <TableRow key={check} className="text-base md:text-lg">
                        <TableCell className="py-3 text-muted-foreground">{check}</TableCell>
                        <TableCell className="py-3 font-medium text-foreground">{result}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Quick credibility beat: many rows, structurally clean. From here we move into descriptive analysis. Tuning details belong
            in the limitations slide, not here.
          </NotesBlock>
        </section>

        {/* 9 */}
        <section>
          <SlideShell
            kicker="Descriptive analysis"
            title="Wins, losses, and ties across all paired rows"
            slideNumber={10}
            concepts="Descriptive analysis: count outcomes before any hypothesis test."
            tags={["Descriptive analysis"]}
          >
            <div className="grid h-full min-h-0 items-center gap-8 lg:grid-cols-[1.25fr_0.75fr] lg:gap-10">
              <SimpleBars data={descriptiveCounts} height={360} />
              <div className="flex min-w-0 flex-col gap-5">
                <BigNumber
                  compact
                  label="Ensemble wins"
                  value={finalNumbers.ensembleWins.toLocaleString()}
                  detail={`Out of ${finalNumbers.rows} paired rows (${finalNumbers.singleWins.toLocaleString()} single-model wins, ${finalNumbers.ties} ties).`}
                />
                <p className="text-base leading-relaxed text-muted-foreground md:text-lg">
                  Descriptive analysis just tallies outcomes — no p-values yet — so the raw dominance pattern is visible before we
                  test it.
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Walk through the three bars: wins, losses, ties. Reinforce that ties are counted honestly, not hidden.
          </NotesBlock>
        </section>

        {/* 10 — Denominator made explicit */}
        <section>
          <SlideShell
            kicker="Descriptive analysis"
            title="Why we report two win rates — and which one the test uses"
            slideNumber={11}
            concepts="Denominator choice: ties stay in the descriptive view but leave the hypothesis-test denominator."
            tags={["Descriptive analysis", "Denominator"]}
          >
            <div className="flex h-full flex-col gap-6">
              <div className="grid gap-5 md:grid-cols-2 md:gap-7">
                <div className="rounded-xl border border-border p-5 md:p-6">
                  <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground md:text-sm">
                    Descriptive (all rows)
                  </p>
                  <p className="mt-2 text-4xl font-semibold tracking-tight text-foreground md:text-5xl">
                    {finalNumbers.allRowWinRate}
                  </p>
                  <p className="mt-3 text-sm leading-snug text-muted-foreground md:text-base">
                    11,910 ensemble wins ÷ <span className="font-medium text-foreground">13,950</span> rows.
                    Ties (261) stay in the denominator, so this rate slightly understates the head-to-head win frequency.
                  </p>
                </div>
                <div className="rounded-xl border border-primary/30 bg-primary/5 p-5 md:p-6">
                  <p className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">
                    Non-tie (used in the test)
                  </p>
                  <p className="mt-2 text-4xl font-semibold tracking-tight text-foreground md:text-5xl">
                    {finalNumbers.nonTieWinRate}
                  </p>
                  <p className="mt-3 text-sm leading-snug text-muted-foreground md:text-base">
                    11,910 ensemble wins ÷ <span className="font-medium text-foreground">13,689</span> non-tied rows. Ties drop out
                    because the hypothesis is win-vs-loss; a tie is neither.
                  </p>
                </div>
              </div>
              <div className="rounded-lg border border-border bg-muted/20 p-4 text-sm leading-snug text-muted-foreground md:p-5 md:text-base">
                <p>
                  The headline test goes one step further and removes MAPE rows for stability — that is why the headline win rate (
                  <span className="font-medium text-foreground">{finalNumbers.headlineWinRate}</span>) sits a little above the
                  descriptive non-tie rate.
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Spell it out: descriptive uses 13,950 in the denominator (ties counted but not as wins). The hypothesis test asks a
            yes/no question, so ties cannot be a success or a failure and are removed — denominator becomes 13,689. The headline test
            additionally drops MAPE rows, which nudges the rate up to 87.50%.
          </NotesBlock>
        </section>

        {/* 11 */}
        <section>
          <SlideShell
            kicker="Descriptive analysis"
            title="Both task types lean ensemble"
            slideNumber={12}
            concepts="Descriptive analysis split by task type; still pre-inferential."
            tags={["Descriptive analysis"]}
          >
            <div className="grid h-full items-center gap-8 lg:grid-cols-[1.12fr_0.88fr] lg:gap-10">
              <SimpleBars data={taskWinRates} height={360} percent />
              <div className="flex flex-col gap-3 text-base leading-relaxed md:text-lg">
                <p className="text-xl font-semibold leading-snug text-foreground md:text-2xl">
                  Both task families lean the same direction.
                </p>
                <p className="text-muted-foreground">
                  Classification and regression were the two halves of the project scope. If only one half supported ensembles, we
                  would not be able to talk about “many prediction tasks”. Both sit far above 50%, so the headline result is not
                  driven by a single task family.
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Point at the dashed 50% line. Clarify these are descriptive splits, not separate formal tests unless asked.
          </NotesBlock>
        </section>

        {/* 12 */}
        <section>
          <SlideShell
            kicker="Descriptive analysis"
            title="Metric-level win rates tell a similar story with nuance"
            slideNumber={13}
            concepts="Descriptive analysis by metric; highlights why proportions beat mixing raw score units."
            tags={["Descriptive analysis"]}
          >
            <div className="grid h-full min-h-0 items-center gap-6 lg:grid-cols-[1.35fr_0.65fr] lg:gap-8">
              <HorizontalRates data={metricWinRates} chartHeight={400} />
              <div className="flex min-w-0 flex-col gap-3 text-base leading-relaxed md:text-lg">
                <p className="text-xl font-semibold leading-snug text-foreground md:text-2xl">
                  Different metrics, same direction.
                </p>
                <p className="text-muted-foreground">
                  Each metric stresses a different failure mode (calibration, ranking, error magnitude). All ten still favour
                  ensembles — strong evidence the win pattern is not a metric-choice artefact.
                </p>
                <p className="text-muted-foreground">
                  Mixing raw differences across metrics is meaningless because units differ; that is why win proportions are the
                  right summary, and exactly the framing the test inherits.
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Keep MAPE light here; slide 17 handles the headline exclusion. Mention recall/precision dips if the audience cares about
                    trade-offs.
          </NotesBlock>
        </section>

        {/* 13 */}
        <section>
          <SlideShell
            kicker="Descriptive analysis"
            title="Model-pair variation keeps the story honest"
            slideNumber={14}
            concepts="Descriptive analysis across the six fixed pairings; reinforces that support is strong but not uniform."
            tags={["Descriptive analysis"]}
          >
            <div className="grid h-full min-h-0 items-center gap-6 lg:grid-cols-[1.35fr_0.65fr] lg:gap-8">
              <HorizontalRates data={modelPairRates} chartHeight={400} />
              <div className="flex min-w-0 flex-col gap-3 text-base leading-relaxed md:text-lg">
                <p className="text-xl font-semibold leading-snug text-foreground md:text-2xl">
                  Same six pairings, different heights.
                </p>
                <p className="text-muted-foreground">
                  Every pair still sits well above 50%, but the spread (≈80% → ≈93%) shows the ensemble edge is stronger for some
                  contrasts than others.
                </p>
                <p className="text-muted-foreground">
                  This is why the conclusion is phrased as strong support inside this benchmark, not a universal law.
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Connect back to slide 5: these are the same six predefined comparisons, now summarized. Useful if examiners ask about
            weaker pairs.
          </NotesBlock>
        </section>

        {/* 14 */}
        <section>
          <SlideShell
            kicker="Statistical inference"
            title="From many rows to a disciplined population statement"
            slideNumber={15}
            concepts="Statistical inference: use sample evidence to judge a broader win-rate pattern."
            tags={["Statistical inference"]}
          >
            <div className="flex h-full flex-col justify-center gap-10">
              <div className="grid gap-8 md:grid-cols-[1fr_auto_1fr] md:items-center">
                <div className="rounded-xl border border-border px-6 py-8 text-center md:px-8">
                  <p className="text-4xl font-semibold tabular-nums text-foreground md:text-5xl">{finalNumbers.rows}</p>
                  <p className="mt-3 text-base text-muted-foreground md:text-lg">paired comparison rows in this sample</p>
                </div>
                <p className="text-center text-3xl font-light text-muted-foreground md:text-4xl">→</p>
                <div className="rounded-xl border border-primary/30 bg-primary/5 px-6 py-8 text-center md:px-8">
                  <p className="text-xl font-medium leading-snug text-foreground md:text-2xl">
                    Question: do ensembles win more than half the meaningful comparisons?
                  </p>
                </div>
              </div>
              <p className="fragment max-w-[52rem] text-lg leading-relaxed text-muted-foreground md:text-xl">
                Next we name the parameter — call it{" "}
                <span className="font-mono text-foreground">π</span>, the population win proportion among non-tied rows — and test
                whether <span className="font-mono text-foreground">π &gt; 0.50</span> using a confidence interval, a p-value, and a
                pre-set decision rule.
              </p>
            </div>
          </SlideShell>
          <NotesBlock>
            Emphasize inference language from lectures: sample, parameter, uncertainty. Preview that the next slide states H0/H1 and the
                    denominator carefully.
          </NotesBlock>
        </section>

        {/* 16 — H0 / H1 with proper notation */}
        <section>
          <SlideShell
            kicker="Hypothesis testing"
            title="Stating the hypotheses precisely"
            slideNumber={16}
            concepts="Hypothesis testing: parameter π (ensemble win proportion among non-tied rows), null and alternative, significance level α."
            tags={["Hypothesis testing", "Population proportion", "α-level"]}
          >
            <div className="flex h-full flex-col gap-6">
              <div className="rounded-xl border border-border bg-muted/15 px-6 py-4 md:px-8 md:py-5">
                <p className="text-sm leading-relaxed text-muted-foreground md:text-base">
                  Let{" "}
                  <span className="font-mono text-foreground">π</span>{" "}
                  = the population proportion of non-tied paired comparisons in which the ensemble wins. We are asking whether{" "}
                  <span className="font-mono text-foreground">π</span> is meaningfully above one-half.
                </p>
              </div>
              <div className="grid gap-5 md:grid-cols-2 md:gap-7">
                <div className="rounded-xl border border-border p-5 md:p-6">
                  <p className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">Null hypothesis</p>
                  <p className="mt-2 font-mono text-2xl font-semibold leading-snug text-foreground md:text-3xl">H₀ : π = 0.50</p>
                  <p className="mt-2 text-sm leading-snug text-muted-foreground md:text-base">
                    Ensembles and single models win equally often — no systematic advantage.
                  </p>
                </div>
                <div className="rounded-xl border border-primary/30 bg-primary/5 p-5 md:p-6">
                  <p className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">Alternative hypothesis</p>
                  <p className="mt-2 font-mono text-2xl font-semibold leading-snug text-foreground md:text-3xl">H₁ : π &gt; 0.50</p>
                  <p className="mt-2 text-sm leading-snug text-muted-foreground md:text-base">
                    Directional, matching the project statement: ensembles win more than half the time.
                  </p>
                </div>
              </div>
              <div className="grid gap-4 md:grid-cols-3 md:gap-5">
                <div className="rounded-lg border border-border bg-muted/20 p-4">
                  <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground md:text-sm">Significance level</p>
                  <p className="mt-1 font-mono text-xl font-semibold text-foreground md:text-2xl">α = 0.05</p>
                </div>
                <div className="rounded-lg border border-border bg-muted/20 p-4">
                  <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground md:text-sm">Trial unit</p>
                  <p className="mt-1 text-sm leading-snug text-foreground md:text-base">One non-tied paired comparison row</p>
                </div>
                <div className="rounded-lg border border-border bg-muted/20 p-4">
                  <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground md:text-sm">Outcome coding</p>
                  <p className="mt-1 text-sm leading-snug text-foreground md:text-base">Success = ensemble wins; failure = single wins</p>
                </div>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Read π as “the long-run share of non-tied comparisons the ensemble would win in this benchmark setup.” H₀ pins it at 0.5;
            H₁ is one-sided because the project statement only matters if ensembles are the winners. α = 0.05 is the textbook default
            we agreed on up front.
          </NotesBlock>
        </section>

        {/* 17 — Test choice & assumptions */}
        <section>
          <SlideShell
            kicker="Hypothesis testing"
            title="Test choice and assumptions"
            slideNumber={17}
            concepts="Why a one-sided exact binomial test on π is the right tool for this paired win/loss question."
            tags={["Hypothesis testing", "Test choice", "Assumptions"]}
          >
            <div className="flex h-full flex-col gap-5">
              <div className="rounded-xl border border-primary/25 bg-primary/5 px-5 py-4 md:px-6 md:py-5">
                <p className="text-base leading-relaxed text-foreground md:text-lg">
                  Each non-tied row is a Bernoulli trial (ensemble win or loss). The natural test for{" "}
                  <span className="font-mono">π &gt; 0.5</span> on a sum of Bernoulli trials is the{" "}
                  <span className="font-semibold">one-sided exact binomial test</span>.
                </p>
              </div>
              <div className="grid gap-4 md:grid-cols-2 md:gap-5">
                <div className="rounded-lg border border-border bg-muted/15 p-4 md:p-5">
                  <p className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">Why this test</p>
                  <ul className="mt-2 space-y-1.5 text-sm leading-snug text-muted-foreground md:text-base">
                    <li>• Outcome is binary on each row — proportion is the right parameter.</li>
                    <li>• Exact binomial avoids large-sample approximations near boundaries.</li>
                    <li>• Matches the descriptive non-tie win-rate framing the audience already saw.</li>
                  </ul>
                </div>
                <div className="rounded-lg border border-border bg-muted/15 p-4 md:p-5">
                  <p className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">Why not a means-based test</p>
                  <ul className="mt-2 space-y-1.5 text-sm leading-snug text-muted-foreground md:text-base">
                    <li>• Metric units differ (accuracy, RMSE, MAPE…), so averaging raw differences across metrics is not meaningful.</li>
                    <li>• Win/loss is metric-scale-free and survives the mixed-metric design.</li>
                  </ul>
                </div>
              </div>
              <div className="rounded-lg border border-border p-4 md:p-5">
                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground md:text-sm">Assumptions and how we handled them</p>
                <ul className="mt-2 space-y-1.5 text-sm leading-snug text-muted-foreground md:text-base">
                  <li>
                    <span className="font-medium text-foreground">Ties.</span> A tie is neither a success nor a failure, so the 261
                    tied rows are excluded from the test denominator (counted and reported separately).
                  </li>
                  <li>
                    <span className="font-medium text-foreground">MAPE stability.</span> MAPE rows are excluded from the headline test
                    because MAPE can explode when targets are near zero; we still report a sensitivity test that includes them.
                  </li>
                  <li>
                    <span className="font-medium text-foreground">Independence.</span> Rows share datasets, splits, and pairs, so
                    independence is approximate. The binomial test is a course-appropriate, conservative approximation to that
                    structure — flagged again in limitations.
                  </li>
                </ul>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Anchor the test choice in two ideas: (1) outcome is binary, so a proportion test is the right tool; (2) metric units
            differ, so a means-based test would mix incompatible scales. Be honest that independence is approximate — that is exactly
            why we revisit it in the limitations slide rather than overclaiming.
          </NotesBlock>
        </section>

        {/* 18 — Headline result + p-value + CI interpretation */}
        <section>
          <SlideShell
            kicker="Hypothesis testing"
            title="Headline result — and how to read it"
            slideNumber={18}
            concepts="p-value interpretation against α; confidence interval for π; decision rule applied to the headline test."
            tags={["p-value", "Confidence interval", "Decision rule"]}
          >
            <div className="grid h-full min-h-0 items-center gap-8 lg:grid-cols-[1fr_1.05fr] lg:gap-10">
              <SimpleBars data={headlineComparison} height={340} percent />
              <div className="flex min-w-0 flex-col gap-4">
                <p className="rounded-lg border border-primary/30 bg-primary/5 px-4 py-3 text-base leading-snug text-foreground md:text-lg">
                  In plain English: the data give very strong evidence that ensembles win clearly more than half of the meaningful
                  comparisons in this benchmark.
                </p>
                <BigNumber
                  compact
                  label="Headline ensemble win rate"
                  value={finalNumbers.headlineWinRate}
                  detail="Non-tied non-MAPE rows (10,797 wins / 12,339 trials)"
                />
                <div className="rounded-lg border border-border bg-muted/15 p-3 md:p-4">
                  <p className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">95% confidence interval for π</p>
                  <p className="mt-1 font-mono text-base leading-snug text-foreground md:text-lg">
                    {finalNumbers.confidenceInterval}
                  </p>
                  <p className="mt-1 text-xs leading-snug text-muted-foreground md:text-sm">
                    Even the lower bound is far above 0.50, which is consistent with rejecting H₀.
                  </p>
                </div>
                <div className="rounded-lg border border-primary/30 bg-primary/5 p-3 md:p-4">
                  <p className="text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">p-value vs α</p>
                  <p className="mt-1 font-mono text-base leading-snug text-foreground md:text-lg">
                    p-value {finalNumbers.pValue} &nbsp;&lt;&nbsp; α = 0.05
                  </p>
                  <p className="mt-1 text-xs leading-snug text-muted-foreground md:text-sm">
                    Decision rule: reject H₀ in favour of H₁. Result: <span className="font-medium text-foreground">{finalNumbers.decision}</span>.
                  </p>
                </div>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Read the p-value as “if H₀ were true, the chance of seeing 10,797-or-more ensemble wins in 12,339 trials is essentially
            zero.” Read the CI as a plausible range for the true win proportion π in this benchmark — and note both endpoints lie far
            above 0.5, which is the same evidence the p-value summarises.
          </NotesBlock>
        </section>

        {/* 19 — MAPE sensitivity */}
        <section>
          <SlideShell
            kicker="Robustness"
            title="MAPE sensitivity check alongside the headline test"
            slideNumber={19}
            concepts="Same hypothesis-testing idea with MAPE included for comparison; headline test still excludes MAPE."
            tags={["Sensitivity analysis"]}
          >
            <div className="grid h-full items-center gap-10 lg:grid-cols-[0.95fr_1.05fr] lg:gap-12">
              <BigNumber label="Non-tie win rate with MAPE included" value="87.00%" detail="Sensitivity check on all metrics" />
              <div className="space-y-5 text-lg leading-relaxed md:text-xl">
                <p>
                  The headline test keeps MAPE out so one unstable metric does not steer the main conclusion, but including MAPE still
                  leaves a high ensemble win rate for context.
                </p>
                <p className="text-muted-foreground">
                  Treat MAPE-driven rows carefully when targets are tiny; that is why it stays a side note, not the headline driver.
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Stress design, not doubt: headline excludes MAPE; sensitivity reassures the audience the direction does not hinge on that
                    choice alone.
          </NotesBlock>
        </section>

        {/* 18 */}
        <section>
          <SlideShell
            kicker="Decision"
            title="What we conclude from the evidence"
            slideNumber={20}
            concepts="Hypothesis testing decision paired with plain-language support for the project statement."
            tags={["Decision", "Interpretation"]}
          >
            <div className="flex h-full flex-col justify-center gap-8">
              <Statement>
                We reject the null hypothesis: ensembles win significantly more than half of the tested non-tied comparisons, so the data
                support the project statement inside this benchmark.
              </Statement>
              <div className="fragment space-y-3 border-l-4 border-primary pl-6 text-lg leading-relaxed text-muted-foreground md:text-xl">
                <p>
                  Headline ensemble win rate <span className="font-semibold text-foreground">{finalNumbers.headlineWinRate}</span> (95%
                  CI {finalNumbers.confidenceInterval}; p-value {finalNumbers.pValue}).
                </p>
                <p>That is strong statistical evidence, framed with the same denominator rules you already explained.</p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Speak slowly: reject H0, then translate to everyday language about support—not “proof for all time.”
          </NotesBlock>
        </section>

        {/* 19 */}
        <section>
          <SlideShell
            kicker="Limitations & takeaway"
            title="Where the result holds—and what we still owe the audience"
            slideNumber={21}
            concepts="Honest scope: benchmark design, dependence between rows, fixed modelling choices."
            tags={["Limitations"]}
          >
            <div className="flex h-full flex-col justify-center gap-8">
              <ul className="max-w-[52rem] list-disc space-y-4 pl-6 text-lg leading-relaxed text-muted-foreground marker:text-primary md:text-xl">
                <li>Results ride on the chosen datasets, metrics, folds, repeats, and the six fixed pairings.</li>
                <li>Rows share structure (datasets, splits, metrics), so independence is approximate even though the binomial test is clear.</li>
                <li>Models used fixed configurations; teams that tune aggressively could see different pairwise outcomes.</li>
                <li>Single models can still win on cost, latency, interpretability, or deployment simplicity.</li>
              </ul>
              <Divider />
              <p className="max-w-[54rem] text-xl font-medium leading-snug text-foreground md:text-2xl">
                Takeaway: the benchmarked classification and regression comparisons overwhelmingly favor ensembles, and the formal test
                backs that pattern—but it is evidence for this scope, not a universal guarantee.
              </p>
            </div>
          </SlideShell>
          <NotesBlock>
            Close calmly: celebrate the strong evidence, restate scope once more in speech if helpful, and invite questions about design
                    trade-offs rather than sounding apologetic.
          </NotesBlock>
        </section>

        {/* 22 — Module-concept recap */}
        <section>
          <SlideShell
            kicker="Module concepts in this project"
            title="Where each lecture concept showed up"
            slideNumber={22}
            concepts="A quick map between module concepts and the slides where we used them."
            tags={["Recap"]}
          >
            <div className="flex h-full flex-col gap-4">
              <p className="max-w-[58rem] text-base leading-relaxed text-muted-foreground md:text-lg">
                Every concept tag you saw at the bottom of a slide ties back to lectures and labs. Together they cover the full
                analytical loop: design, describe, infer, decide, qualify.
              </p>
              <div className="grid gap-3 md:grid-cols-2 md:gap-4">
                {[
                  { c: "Research design & paired comparison", s: "Slides 3 – 8" },
                  { c: "Resampling (folds & repeats)", s: "Slide 7" },
                  { c: "Descriptive analysis & denominator choice", s: "Slides 10 – 14" },
                  { c: "Statistical inference (sample → population)", s: "Slide 15" },
                  { c: "Hypothesis testing on a population proportion (π, α)", s: "Slides 16 – 17" },
                  { c: "p-value, confidence interval, decision rule", s: "Slide 18" },
                  { c: "Sensitivity / robustness check", s: "Slide 19" },
                  { c: "Interpretation & limitations", s: "Slides 20 – 21" },
                ].map(({ c, s }) => (
                  <div key={c} className="flex items-start justify-between gap-4 rounded-lg border border-border bg-muted/15 px-4 py-3">
                    <span className="text-sm leading-snug text-foreground md:text-base">{c}</span>
                    <span className="shrink-0 text-xs font-semibold uppercase tracking-wide text-primary md:text-sm">{s}</span>
                  </div>
                ))}
              </div>
              <p className="text-sm leading-snug text-muted-foreground md:text-base">
                The thread running through all of these: a broad statement needs broad, paired evidence — then a disciplined
                inferential step turns that evidence into a defensible conclusion.
              </p>
            </div>
          </SlideShell>
          <NotesBlock>
            Closing slide: use it as a quick walk-back so the audience leaves with both the result and the methodology vocabulary.
            Skip it if time is short — the per-slide tags already carry the same information.
          </NotesBlock>
        </section>
      </div>
    </div>
  )
}

export default App
