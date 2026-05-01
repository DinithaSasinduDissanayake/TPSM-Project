import { useEffect } from "react"
import Reveal from "reveal.js"
import Notes from "reveal.js/plugin/notes"
import "reveal.js/reveal.css"
import { ArrowRight, CheckCircle2 } from "lucide-react"
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
import { Badge } from "@/components/ui/badge"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
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
  TableRow,
} from "@/components/ui/table"
import {
  descriptiveCounts,
  finalNumbers,
  headlineComparison,
  metricWinRates,
  modelPairExamples,
  modelPairRates,
  readinessRows,
  taskWinRates,
} from "@/data/analysis"

const rateConfig = {
  value: { label: "Win rate", color: "var(--chart-3)" },
} satisfies ChartConfig

function NotesBlock({ children }: { children: string }) {
  return <aside className="notes">{children}</aside>
}

function BigNumber({ label, value, detail }: { label: string; value: string; detail?: string }) {
  return (
    <div className="flex flex-col gap-2">
      <p className="text-base text-muted-foreground">{label}</p>
      <p className="text-7xl font-semibold leading-none tracking-normal text-foreground">{value}</p>
      {detail ? <p className="text-xl leading-relaxed text-muted-foreground">{detail}</p> : null}
    </div>
  )
}

function Statement({ children }: { children: string }) {
  return <p className="max-w-[900px] text-4xl font-medium leading-tight text-foreground">{children}</p>
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

function HorizontalRates({ data }: { data: Array<{ name: string; value: number }> }) {
  return (
    <ChartContainer config={rateConfig} className="h-[390px] w-full">
      <BarChart data={data} layout="vertical" margin={{ top: 8, right: 48, left: 170, bottom: 8 }}>
        <CartesianGrid horizontal={false} />
        <XAxis type="number" domain={[0, 100]} tickFormatter={(value) => `${value}%`} />
        <YAxis dataKey="name" type="category" width={165} tickMargin={8} />
        <ReferenceLine x={50} stroke="var(--muted-foreground)" strokeDasharray="5 5" />
        <ChartTooltip content={<ChartTooltipContent />} />
        <Bar dataKey="value" fill="var(--color-value)" radius={[0, 5, 5, 0]}>
          <LabelList
            dataKey="value"
            position="right"
            formatter={(value: unknown) => `${Number(value).toFixed(1)}%`}
            className="fill-foreground text-sm font-medium"
          />
        </Bar>
      </BarChart>
    </ChartContainer>
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
        <section>
          <SlideShell kicker="TPSM project" title="Do ensembles perform better than single models?" slideNumber={1}>
            <div className="flex h-full flex-col justify-center gap-10">
              <Statement>We tested a broad machine-learning statement using descriptive and inferential analysis.</Statement>
              <div className="flex flex-wrap gap-3">
                <Badge>classification</Badge>
                <Badge variant="secondary">regression</Badge>
                <Badge variant="outline">no time series</Badge>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Start with the project statement. Say this is a student analysis project, not a leaderboard-style benchmark.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Claim" title="What we are trying to prove" slideNumber={2}>
            <div className="grid h-full grid-cols-[1fr_0.8fr] items-center gap-12">
              <Statement>Ensemble models perform better than single models in many prediction tasks.</Statement>
              <Card>
                <CardHeader>
                  <CardTitle>Operational meaning</CardTitle>
                  <CardDescription>How the statement becomes testable</CardDescription>
                </CardHeader>
                <CardContent className="text-2xl leading-relaxed">
                  “Better” means the ensemble gets the better metric result in a paired comparison.
                </CardContent>
              </Card>
            </div>
          </SlideShell>
          <NotesBlock>
            Define better before showing numbers. The analysis turns a broad wording into a measurable win/loss question.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Problem" title="One model score cannot answer this claim" slideNumber={3}>
            <div className="grid h-full grid-cols-2 items-center gap-14">
              <div className="flex flex-col gap-5 text-3xl font-medium leading-tight">
                <p>One dataset can favor one model.</p>
                <p>One split can be lucky.</p>
                <p>One metric can hide another weakness.</p>
              </div>
              <Card>
                <CardContent className="p-8 text-3xl font-semibold leading-tight">
                  We needed many controlled comparisons, not one accuracy result.
                </CardContent>
              </Card>
            </div>
          </SlideShell>
          <NotesBlock>
            Use this as motivation. One score is not enough for a claim about many prediction tasks.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Method" title="From datasets to evidence" slideNumber={4}>
            <div className="grid h-full grid-cols-[1fr_auto_1fr_auto_1fr_auto_1fr] items-center gap-4">
              {["Datasets", "Models", "Paired comparisons", "Analysis"].map((step, index) => (
                <div key={step} className="contents">
                  <Card>
                    <CardContent className="flex min-h-36 items-center justify-center p-5 text-center text-2xl font-medium">
                      {step}
                    </CardContent>
                  </Card>
                  {index < 3 ? <ArrowRight className="text-muted-foreground" /> : null}
                </div>
              ))}
            </div>
          </SlideShell>
          <NotesBlock>
            Keep method simple: data, predictive models, paired comparison rows, then descriptive and inferential analysis.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Paired row" title="One row compares two models under the same context" slideNumber={5}>
            <div className="grid h-full grid-cols-[0.9fr_1.1fr] items-center gap-12">
              <div className="flex flex-col gap-5 text-2xl leading-relaxed text-muted-foreground">
                <p>Same dataset split.</p>
                <p>Same metric.</p>
                <p>Same model-pair comparison.</p>
                <p>Then we calculate <span className="font-medium text-foreground">difference_value</span>.</p>
              </div>
              <Card>
                <CardContent className="grid grid-cols-1 gap-5 p-7 text-2xl">
                  <p><Badge>positive</Badge> ensemble wins</p>
                  <p><Badge variant="secondary">negative</Badge> single model wins</p>
                  <p><Badge variant="outline">zero</Badge> tie</p>
                </CardContent>
              </Card>
            </div>
          </SlideShell>
          <NotesBlock>
            Explain paired comparison. It is not two unrelated groups; each row compares models in the same context.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Predictive modelling" title="Models generated the evidence; statistics answered the claim" slideNumber={6}>
            <div className="flex h-full flex-col justify-center gap-10">
              <div className="grid grid-cols-3 gap-8">
                <BigNumber label="Rows" value={finalNumbers.rows} detail="paired observations" />
                <BigNumber label="Datasets" value={finalNumbers.datasets} detail="classification + regression" />
                <BigNumber label="Model pairs" value={finalNumbers.modelPairs} detail="predefined comparisons" />
              </div>
              <p className="max-w-[920px] text-2xl leading-relaxed text-muted-foreground">
                Models were evaluated using fixed project configurations; deeper hyperparameter tuning may change results.
              </p>
            </div>
          </SlideShell>
          <NotesBlock>
            This is the predictive modelling section. Models generated metric scores; the statistical analysis interprets the pattern.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Model-pair design" title="Model pairs were predefined comparison pairs" slideNumber={7}>
            <div className="grid h-full grid-cols-[1fr_0.9fr] items-center gap-12">
              <div className="flex flex-col gap-4">
                {modelPairExamples.map((pair) => (
                  <Card key={pair}>
                    <CardContent className="p-5 text-2xl font-medium">{pair}</CardContent>
                  </Card>
                ))}
              </div>
              <div className="flex flex-col gap-6">
                <Statement>Some pairs are cleaner counterparts than others.</Statement>
                <p className="text-2xl leading-relaxed text-muted-foreground">
                  Results reflect the selected model-pair design, not a perfect isolation of only ensemble technique.
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Say Decision Tree vs Random Forest is cleaner than some other pairings. This protects the conclusion from overclaiming.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Data readiness" title="The comparison table was ready for analysis" slideNumber={8}>
            <div className="grid h-full grid-cols-[0.75fr_1.25fr] items-center gap-12">
              <Statement>No time series, valid paired rows, usable metric columns.</Statement>
              <Table>
                <TableBody>
                  {readinessRows.map(([check, result]) => (
                    <TableRow key={check}>
                      <TableCell className="py-4 text-xl">{check}</TableCell>
                      <TableCell className="py-4 text-xl font-medium text-foreground">{result}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </SlideShell>
          <NotesBlock>
            Move quickly. This is only to show the dataset was clean enough to support the analysis.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Descriptive analysis" title="First, count wins, losses, and ties" slideNumber={9}>
            <div className="grid h-full grid-cols-[1.1fr_0.9fr] items-center gap-10">
              <SimpleBars data={descriptiveCounts} height={420} />
              <div className="flex flex-col gap-8">
                <BigNumber label="Ensemble wins" value="11,910" />
                <p className="text-2xl leading-relaxed text-muted-foreground">
                  Descriptive analysis shows the pattern before hypothesis testing.
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            This is descriptive analytics: count what happened. Do not discuss p-values here.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Descriptive analysis" title="Overall win rates were high" slideNumber={10}>
            <div className="grid h-full grid-cols-2 items-center gap-14">
              <BigNumber label="All-row win rate" value={finalNumbers.allRowWinRate} detail="ties included in denominator" />
              <BigNumber label="Non-tie win rate" value={finalNumbers.nonTieWinRate} detail="ties excluded from denominator" />
            </div>
          </SlideShell>
          <NotesBlock>
            Explain denominator difference. The non-tie win rate aligns more closely with the hypothesis-test denominator.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Task types" title="Both task types favored ensembles" slideNumber={11}>
            <div className="grid h-full grid-cols-[1.15fr_0.85fr] items-center gap-10">
              <SimpleBars data={taskWinRates} height={420} percent />
              <p className="text-3xl font-medium leading-tight">
                Classification and regression both stayed far above the 50% reference line.
              </p>
            </div>
          </SlideShell>
          <NotesBlock>
            Point out the 50 percent reference line. Avoid saying this proves all future tasks behave this way.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Metrics" title="The advantage was broad, but not identical across metrics" slideNumber={12}>
            <div className="grid h-full grid-cols-[1.25fr_0.75fr] items-center gap-8">
              <HorizontalRates data={metricWinRates} />
              <div className="flex flex-col gap-5 text-2xl leading-relaxed text-muted-foreground">
                <p>Most metrics were above 50%.</p>
                <p>MAPE stayed cautionary.</p>
                <p>Metric scales differ, so win proportion is clearer than raw mixed differences.</p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            This slide replaces dense PNGs with readable chart labels. Mention MAPE caution briefly.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Variation" title="The pattern was not equally strong everywhere" slideNumber={13}>
            <div className="grid h-full grid-cols-[1.25fr_0.75fr] items-center gap-8">
              <HorizontalRates data={modelPairRates} />
              <div className="flex flex-col gap-5">
                <p className="text-3xl font-medium leading-tight">
                  Model-pair variation matters.
                </p>
                <p className="text-2xl leading-relaxed text-muted-foreground">
                  The conclusion is broad support, not universal dominance.
                </p>
                <p className="text-xl leading-relaxed text-muted-foreground">
                  Dataset variation was also present, so the final claim stays within tested benchmark conditions.
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            Use this as the honesty slide before inference. Some groups are stronger than others.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Statistical inference" title="We used sample evidence to make a cautious population claim" slideNumber={14}>
            <div className="grid h-full grid-cols-[1fr_auto_1fr] items-center gap-8">
              <Card>
                <CardContent className="p-8 text-center text-3xl font-medium">13,950 observed paired comparisons</CardContent>
              </Card>
              <ArrowRight className="text-muted-foreground" />
              <Card>
                <CardContent className="p-8 text-center text-3xl font-medium">Claim about ensemble performance in tested benchmark conditions</CardContent>
              </Card>
            </div>
          </SlideShell>
          <NotesBlock>
            Connect to lecture concept: statistical inference. Sample evidence supports a broader but bounded conclusion.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Hypothesis testing" title="We tested a population proportion" slideNumber={15}>
            <div className="grid h-full grid-cols-2 items-center gap-10">
              <Card>
                <CardHeader>
                  <CardTitle className="text-3xl">H0</CardTitle>
                  <CardDescription className="text-xl">No ensemble advantage in win frequency</CardDescription>
                </CardHeader>
                <CardContent className="text-3xl font-semibold">p = 0.50</CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <CardTitle className="text-3xl">H1</CardTitle>
                  <CardDescription className="text-xl">Ensembles win more often</CardDescription>
                </CardHeader>
                <CardContent className="text-3xl font-semibold">p &gt; 0.50</CardContent>
              </Card>
            </div>
          </SlideShell>
          <NotesBlock>
            Define success as ensemble win among non-tied rows. This is why population proportion is the right lecture concept.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Hypothesis result" title="The headline win rate was far above 50%" slideNumber={16}>
            <div className="grid h-full grid-cols-[1fr_0.9fr] items-center gap-12">
              <SimpleBars data={headlineComparison} height={390} percent />
              <div className="flex flex-col gap-8">
                <BigNumber label="Headline win rate" value={finalNumbers.headlineWinRate} detail="excluding MAPE and test-denominator ties" />
                <p className="text-2xl font-medium leading-tight">
                  95% CI: {finalNumbers.confidenceInterval}
                </p>
                <p className="text-2xl font-medium leading-tight">
                  p-value: {finalNumbers.pValue}; decision: {finalNumbers.decision}
                </p>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            This is the main result. The CI should be read as the estimated ensemble win proportion range in this setup.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="MAPE caution" title="MAPE was kept out of the headline test" slideNumber={17}>
            <div className="grid h-full grid-cols-[0.9fr_1.1fr] items-center gap-12">
              <BigNumber label="Sensitivity including MAPE" value="87.00%" detail="same conclusion, still cautionary" />
              <p className="text-3xl font-medium leading-tight">
                MAPE can behave poorly when actual target values are close to zero, so it should not drive the main claim.
              </p>
            </div>
          </SlideShell>
          <NotesBlock>
            Keep this short. MAPE did not change the conclusion, but the headline test excludes it for methodological caution.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Final decision" title="The statement is supported within our tested scope" slideNumber={18}>
            <div className="flex h-full flex-col justify-center gap-9">
              <Statement>We reject H0 and conclude that ensembles won significantly more often than 50% in this project.</Statement>
              <div className="flex gap-3">
                <Badge>87.50% win rate</Badge>
                <Badge variant="secondary">95% CI: 86.91%-88.08%</Badge>
                <Badge variant="outline">p &lt; 0.001</Badge>
              </div>
            </div>
          </SlideShell>
          <NotesBlock>
            This is the decision slide. Say supported within classification and regression benchmark comparisons.
          </NotesBlock>
        </section>

        <section>
          <SlideShell kicker="Limitations" title="Strong evidence does not mean universal proof" slideNumber={19}>
            <div className="grid h-full grid-cols-2 gap-8">
              {[
                "Some model pairs are cleaner counterparts than others.",
                "Rows share datasets, folds, metrics, and model pairs, so independence is approximate.",
                "Fixed configurations mean deeper tuning may change results.",
                "Single models may still be preferred for interpretability, speed, simplicity, or deployment cost.",
              ].map((item) => (
                <Card key={item}>
                  <CardContent className="flex h-full items-start gap-4 p-6 text-2xl leading-snug">
                    <CheckCircle2 className="mt-1 text-primary" />
                    <span>{item}</span>
                  </CardContent>
                </Card>
              ))}
            </div>
          </SlideShell>
          <NotesBlock>
            End honestly. The answer is not that ensembles are always best; it is that the tested evidence supports the statement.
          </NotesBlock>
        </section>
      </div>
    </div>
  )
}

export default App
