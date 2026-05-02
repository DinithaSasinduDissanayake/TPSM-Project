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

/** Tiny inline diagram of 5-fold cross-validation: 5 columns × 5 rows where the diagonal is the test fold. */
function FoldsDiagram() {
  const folds = [0, 1, 2, 3, 4]
  return (
    <div className="flex flex-col gap-2" aria-label="Five-fold cross-validation diagram">
      <div className="flex items-center gap-2 text-xs text-muted-foreground md:text-sm">
        <span className="inline-block h-3 w-3 rounded-sm border border-border bg-muted" /> train
        <span className="ml-3 inline-block h-3 w-3 rounded-sm border border-primary bg-primary/70" /> test
      </div>
      <div className="flex flex-col gap-1.5">
        {folds.map((row) => (
          <div key={row} className="flex items-center gap-2">
            <span className="w-12 shrink-0 text-xs text-muted-foreground md:text-sm">Run {row + 1}</span>
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
      <p className="mt-1 text-xs leading-snug text-muted-foreground md:text-sm">
        The test slice rotates each run, then the whole cycle repeats — so every pair contributes many comparison rows.
      </p>
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
          <SlideShell kicker="TPSM — research question" title="Do ensembles outperform single models across many comparisons?" slideNumber={1}>
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

        {/* 5 — Model pairs split by task type */}
        <section>
          <SlideShell
            kicker="Model design"
            title="Six predefined model pairings — three per task type"
            slideNumber={5}
            concepts="Continues the methodology: same fixed pairings drive every row in the comparison table."
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
            slideNumber={6}
            concepts="Folds and repeats: each pair is re-evaluated under many split contexts so the evidence is not a single roll of the dice."
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
            slideNumber={7}
            concepts="Paired comparison: both models see the same context before we read off who won."
          >
            <div className="grid h-full items-center gap-10 md:grid-cols-2 md:gap-14">
              <ul className="space-y-3 text-lg leading-relaxed text-muted-foreground md:text-xl">
                <li>One task type and dataset</li>
                <li>One fold or repeat (same split context)</li>
                <li>One metric and one of the six predefined pairings</li>
                <li>
                  A stored <span className="font-medium text-foreground">difference_value</span> captures who won on that row
                </li>
              </ul>
              <div className="space-y-4 rounded-xl border border-border bg-muted/20 p-6 md:p-7">
                <p className="text-sm font-semibold uppercase tracking-wide text-primary">Reading the sign</p>
                <ul className="space-y-3 text-lg leading-relaxed md:text-xl">
                  <li>
                    <span className="font-semibold text-emerald-700 dark:text-emerald-400">Positive</span>
                    <span className="text-muted-foreground"> — ensemble wins the row</span>
                  </li>
                  <li>
                    <span className="font-semibold text-amber-800 dark:text-amber-300">Negative</span>
                    <span className="text-muted-foreground"> — single model wins the row</span>
                  </li>
                  <li>
                    <span className="font-semibold text-foreground">Zero</span>
                    <span className="text-muted-foreground"> — tie</span>
                  </li>
                </ul>
              </div>
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
            slideNumber={8}
            concepts="Pre-descriptive checkpoint: how much comparison data we have, and that it is structurally clean."
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
            slideNumber={9}
            concepts="Descriptive analysis: count outcomes before any hypothesis test."
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
            slideNumber={10}
            concepts="Denominator choice: ties stay in the descriptive view but leave the hypothesis-test denominator."
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
            slideNumber={11}
            concepts="Descriptive analysis split by task type; still pre-inferential."
          >
            <div className="grid h-full items-center gap-8 lg:grid-cols-[1.12fr_0.88fr] lg:gap-10">
              <SimpleBars data={taskWinRates} height={380} percent />
              <p className="text-2xl font-medium leading-snug md:text-3xl">
                Each bar is the ensemble win rate among non-tied rows for that task family—well above the 50% reference line shown on
                the chart.
              </p>
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
            slideNumber={12}
            concepts="Descriptive analysis by metric; highlights why proportions beat mixing raw score units."
          >
            <div className="grid h-full items-start gap-6 lg:grid-cols-[1.2fr_0.8fr] lg:gap-8">
              <HorizontalRates data={metricWinRates} chartHeight={400} />
              <div className="space-y-4 text-lg leading-relaxed text-muted-foreground md:text-xl">
                <p>Most metrics sit above 50%, showing the ensemble edge is broad.</p>
                <p>MAPE is useful contextually but noisy when targets are near zero—called out again when we discuss the headline test.</p>
                <p>Because units differ, we emphasize win proportions rather than averaging raw differences across metrics.</p>
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
            slideNumber={13}
            concepts="Descriptive analysis across the six fixed pairings; reinforces that support is strong but not uniform."
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
            slideNumber={14}
            concepts="Statistical inference: use sample evidence to judge a broader win-rate pattern."
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
                Hypothesis testing gives a structured way to answer that with a population proportion, a confidence interval, and a
                decision rule—while keeping the interpretation tied to this benchmark.
              </p>
            </div>
          </SlideShell>
          <NotesBlock>
            Emphasize inference language from lectures: sample, parameter, uncertainty. Preview that the next slide states H0/H1 and the
                    denominator carefully.
          </NotesBlock>
        </section>

        {/* 15 */}
        <section>
          <SlideShell
            kicker="Hypothesis testing"
            title="Hypotheses, denominator, and headline test framing"
            slideNumber={15}
            concepts="Hypothesis testing on a population proportion; ties handled separately; MAPE excluded from the headline test."
          >
            <div className="grid h-full gap-8 lg:grid-cols-2 lg:gap-10">
              <div className="flex flex-col gap-6 rounded-xl border border-border p-6 md:p-8">
                <div>
                  <p className="text-sm font-semibold uppercase tracking-wide text-primary">Null hypothesis</p>
                  <p className="mt-2 text-2xl font-semibold leading-snug md:text-3xl">Ensemble win proportion = 0.50</p>
                  <p className="mt-2 text-muted-foreground">No systematic advantage in win frequency.</p>
                </div>
                <Divider />
                <div>
                  <p className="text-sm font-semibold uppercase tracking-wide text-primary">Alternative hypothesis</p>
                  <p className="mt-2 text-2xl font-semibold leading-snug md:text-3xl">Ensemble win proportion &gt; 0.50</p>
                  <p className="mt-2 text-muted-foreground">Matches the direction of the project statement.</p>
                </div>
              </div>
              <div className="flex flex-col justify-center space-y-5 rounded-xl border border-border bg-muted/15 p-6 text-lg leading-relaxed md:p-8 md:text-xl">
                <p>
                  <span className="font-semibold text-foreground">Population proportion setup:</span> each non-tied row is a Bernoulli
                  trial—success if the ensemble wins, failure if the single model wins.
                </p>
                <p>
                  <span className="font-semibold text-foreground">Ties:</span> counted and reported, but excluded from the test denominator.
                </p>
                <p>
                  <span className="font-semibold text-foreground">MAPE:</span> excluded from the headline test because it can explode when
                  targets approach zero; sensitivity including MAPE is shown next to the headline result.
                </p>
                <p>
                  <span className="font-semibold text-foreground">Decision rule:</span> one-sided exact binomial test at α = 0.05.
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            If asked about notation, say π or “win probability” for the population parameter—avoid confusing it with the p-value on the
                    next slide.
          </NotesBlock>
        </section>

        {/* 16 */}
        <section>
          <SlideShell
            kicker="Hypothesis testing"
            title="Headline result: ensemble wins far more than half the non-tied comparisons"
            slideNumber={16}
            concepts="Hypothesis testing outcome with confidence interval for the ensemble win proportion."
          >
            <div className="grid h-full items-center gap-10 lg:grid-cols-[1fr_0.95fr] lg:gap-12">
              <SimpleBars data={headlineComparison} height={360} percent />
              <div className="flex flex-col gap-6">
                <BigNumber
                  label="Headline ensemble win rate"
                  value={finalNumbers.headlineWinRate}
                  detail="excluding MAPE and test-denominator ties"
                />
                <p className="text-xl font-medium leading-snug md:text-2xl">
                  95% confidence interval (ensemble win proportion): {finalNumbers.confidenceInterval}
                </p>
                <p className="text-xl font-medium leading-snug md:text-2xl">
                  p-value {finalNumbers.pValue}; decision: {finalNumbers.decision}
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Slow down on the confidence interval: it estimates the long-run win proportion for this benchmark-style sampling story, not
                    every future dataset.
          </NotesBlock>
        </section>

        {/* 17 */}
        <section>
          <SlideShell
            kicker="Robustness"
            title="MAPE sensitivity check alongside the headline test"
            slideNumber={17}
            concepts="Same hypothesis-testing idea with MAPE included for comparison; headline test still excludes MAPE."
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
            slideNumber={18}
            concepts="Hypothesis testing decision paired with plain-language support for the project statement."
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
            slideNumber={19}
            concepts="Honest scope: benchmark design, dependence between rows, fixed modelling choices."
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
      </div>
    </div>
  )
}

export default App
