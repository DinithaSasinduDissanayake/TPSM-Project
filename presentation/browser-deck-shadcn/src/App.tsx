import { useEffect, useMemo, useState } from "react"
import {
  ArrowLeft,
  ArrowRight,
  BarChart3,
  Database,
  ShieldCheck,
  Target,
} from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"
import { Separator } from "@/components/ui/separator"
import { cn } from "@/lib/utils"

type Slide = {
  eyebrow: string
  title: string
  subtitle?: string
  kind: "cover" | "problem" | "method" | "chart" | "matrix" | "decision"
}

const slides: Slide[] = [
  {
    eyebrow: "TPSM Project",
    title: "Ensemble Models vs Single Models",
    subtitle:
      "A browser-native evidence deck redesigned with reusable shadcn-style presentation components.",
    kind: "cover",
  },
  {
    eyebrow: "Problem Statement",
    title: "Do ensembles consistently beat single models?",
    subtitle:
      "The answer has to survive dataset variance, metric differences, and failed or warning-heavy runs.",
    kind: "problem",
  },
  {
    eyebrow: "Evidence Pipeline",
    title: "Fair comparison comes before model judgment.",
    subtitle:
      "Each comparison keeps split, dataset, and metric aligned so differences are paired instead of accidental.",
    kind: "method",
  },
  {
    eyebrow: "Descriptive Analysis",
    title: "Task-level win rate gives the first signal.",
    subtitle:
      "Useful as an overview, but too coarse for the final claim without metric and dataset breakdowns.",
    kind: "chart",
  },
  {
    eyebrow: "Dataset Effects",
    title: "The strongest evidence is uneven across datasets.",
    subtitle:
      "Dataset extremes explain why a simple universal claim would overstate the result.",
    kind: "matrix",
  },
  {
    eyebrow: "Final Decision",
    title: "Ensembles often help, but not always.",
    subtitle:
      "The defendable conclusion is conditional: task, dataset, metric, and run quality all matter.",
    kind: "decision",
  },
]

const tags = ["Classification", "Regression", "Paired evidence"]

function App() {
  const [index, setIndex] = useState(() => getInitialIndex())
  const slide = slides[index]
  const progress = ((index + 1) / slides.length) * 100

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (["ArrowRight", "PageDown", " "].includes(event.key)) {
        setIndex((value) => Math.min(value + 1, slides.length - 1))
      }
      if (["ArrowLeft", "PageUp"].includes(event.key)) {
        setIndex((value) => Math.max(value - 1, 0))
      }
      if (event.key === "Home") setIndex(0)
      if (event.key === "End") setIndex(slides.length - 1)
    }

    window.addEventListener("keydown", onKeyDown)
    return () => window.removeEventListener("keydown", onKeyDown)
  }, [])

  useEffect(() => {
    window.history.replaceState(null, "", `#${index + 1}`)
  }, [index])

  const content = useMemo(() => {
    switch (slide.kind) {
      case "cover":
        return <CoverSlide slide={slide} />
      case "problem":
        return <ProblemSlide slide={slide} />
      case "method":
        return <MethodSlide slide={slide} />
      case "chart":
        return <ChartSlide slide={slide} />
      case "matrix":
        return <MatrixSlide slide={slide} />
      case "decision":
        return <DecisionSlide slide={slide} />
    }
  }, [slide])

  return (
    <div className="min-h-screen overflow-hidden bg-background text-foreground">
      <main className="relative h-screen w-screen">{content}</main>

      <div className="fixed bottom-5 left-1/2 z-20 flex -translate-x-1/2 items-center gap-3 rounded-full border bg-background/88 px-3 py-2 shadow-lg backdrop-blur">
        <Button
          variant="ghost"
          size="icon"
          onClick={() => setIndex((value) => Math.max(value - 1, 0))}
          aria-label="Previous slide"
        >
          <ArrowLeft data-icon="inline-start" />
        </Button>
        <div className="flex min-w-40 flex-col gap-1">
          <span className="text-center text-xs font-medium text-muted-foreground">
            {index + 1} / {slides.length}
          </span>
          <Progress value={progress} />
        </div>
        <Button
          variant="ghost"
          size="icon"
          onClick={() => setIndex((value) => Math.min(value + 1, slides.length - 1))}
          aria-label="Next slide"
        >
          <ArrowRight data-icon="inline-end" />
        </Button>
      </div>
    </div>
  )
}

function getInitialIndex() {
  const parsed = Number.parseInt(window.location.hash.replace("#", ""), 10)
  if (!Number.isInteger(parsed)) return 0
  return Math.min(Math.max(parsed - 1, 0), slides.length - 1)
}

function SlideShell({
  slide,
  children,
  dark = false,
  className,
}: {
  slide: Slide
  children: React.ReactNode
  dark?: boolean
  className?: string
}) {
  return (
    <section
      className={cn(
        "relative h-screen w-screen overflow-hidden px-16 py-12",
        dark ? "bg-zinc-950 text-white" : "bg-[radial-gradient(circle_at_top_left,hsl(var(--muted))_0,transparent_28rem),hsl(var(--background))]",
        className,
      )}
    >
      {children}
      <div className={cn("absolute right-12 bottom-10 text-xs uppercase tracking-[0.22em]", dark ? "text-white/45" : "text-muted-foreground")}>
        {slide.eyebrow}
      </div>
    </section>
  )
}

function DeckHeading({ slide, light = false }: { slide: Slide; light?: boolean }) {
  return (
    <div className="flex max-w-4xl flex-col gap-5">
      <Badge variant={light ? "secondary" : "outline"} className="w-fit">
        {slide.eyebrow}
      </Badge>
      <h1 className="text-6xl leading-[0.94] font-semibold tracking-normal md:text-7xl">
        {slide.title}
      </h1>
      {slide.subtitle ? (
        <p className={cn("max-w-3xl text-xl leading-8", light ? "text-white/72" : "text-muted-foreground")}>
          {slide.subtitle}
        </p>
      ) : null}
    </div>
  )
}

function CoverSlide({ slide }: { slide: Slide }) {
  return (
    <SlideShell slide={slide} dark className="grid items-center">
      <div className="absolute inset-0 opacity-30">
        <img
          src="/images/diagrams/final_message_map.png"
          alt=""
          className="h-full w-full object-cover"
        />
      </div>
      <div className="absolute inset-0 bg-gradient-to-r from-zinc-950 via-zinc-950/86 to-zinc-950/25" />
      <div className="relative z-10 flex flex-col gap-8">
        <DeckHeading slide={slide} light />
        <div className="flex gap-3">
          {tags.map((tag) => (
            <Badge key={tag} variant="secondary" className="px-4 py-1.5 text-sm">
              {tag}
            </Badge>
          ))}
        </div>
      </div>
    </SlideShell>
  )
}

function ProblemSlide({ slide }: { slide: Slide }) {
  const questions = [
    ["Dataset", "Does the result change by dataset?"],
    ["Metric", "Does the result change by metric?"],
    ["Reliability", "Can warnings and failed runs change the final claim?"],
  ]

  return (
    <SlideShell slide={slide} className="grid grid-cols-[1fr_0.82fr] items-center gap-14">
      <DeckHeading slide={slide} />
      <div className="flex flex-col gap-4">
        {questions.map(([label, text], questionIndex) => (
          <Card key={label} className="shadow-xl">
            <CardHeader>
              <div className="flex items-center justify-between">
                <Badge variant="outline">{label}</Badge>
                <span className="text-sm font-medium text-muted-foreground">
                  0{questionIndex + 1}
                </span>
              </div>
              <CardTitle className="text-2xl tracking-normal">{text}</CardTitle>
            </CardHeader>
          </Card>
        ))}
      </div>
    </SlideShell>
  )
}

function MethodSlide({ slide }: { slide: Slide }) {
  const steps = [
    { icon: Database, title: "Same split", text: "Matched train/test split for both model types." },
    { icon: Target, title: "Same metric", text: "Task-specific score compared under one metric definition." },
    { icon: ShieldCheck, title: "Same dataset", text: "Dataset-level context retained before aggregation." },
  ]

  return (
    <SlideShell slide={slide} className="grid grid-rows-[auto_1fr] gap-8">
      <DeckHeading slide={slide} />
      <div className="grid grid-cols-[0.9fr_1.1fr] gap-8">
        <div className="grid content-start gap-4">
          {steps.map(({ icon: Icon, title, text }) => (
            <Card key={title}>
              <CardHeader>
                <CardTitle className="flex items-center gap-3 text-2xl tracking-normal">
                  <span className="grid size-10 place-items-center rounded-md bg-primary text-primary-foreground">
                    <Icon />
                  </span>
                  {title}
                </CardTitle>
                <CardDescription className="text-base">{text}</CardDescription>
              </CardHeader>
            </Card>
          ))}
        </div>
        <Card className="overflow-hidden shadow-2xl">
          <CardContent className="grid h-full place-items-center p-6">
            <img
              src="/images/diagrams/paired_comparison_logic.png"
              alt="Paired comparison logic"
              className="max-h-[46vh] w-full object-contain"
            />
          </CardContent>
        </Card>
      </div>
    </SlideShell>
  )
}

function ChartSlide({ slide }: { slide: Slide }) {
  return (
    <SlideShell slide={slide} className="grid grid-cols-[0.68fr_1.18fr] items-center gap-10">
      <div className="flex flex-col gap-6">
        <DeckHeading slide={slide} />
        <Separator />
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-3 tracking-normal">
              <BarChart3 />
              Reading
            </CardTitle>
            <CardDescription className="text-base">
              Use this as overview only. Next slide must explain dataset spread.
            </CardDescription>
          </CardHeader>
        </Card>
      </div>
      <ChartFrame src="/images/charts/analysis_winrate_by_task.png" alt="Win rate by task" />
    </SlideShell>
  )
}

function MatrixSlide({ slide }: { slide: Slide }) {
  return (
    <SlideShell slide={slide} className="grid grid-cols-[1.18fr_0.72fr] items-center gap-10">
      <ChartFrame
        src="/images/charts/analysis_dataset_winrate_extremes.png"
        alt="Dataset win rate extremes"
      />
      <div className="flex flex-col gap-6">
        <DeckHeading slide={slide} />
        <div className="grid grid-cols-2 gap-4">
          <MetricCard label="Best use" value="Qualify conclusion" />
          <MetricCard label="Main risk" value="Over-generalizing" />
        </div>
      </div>
    </SlideShell>
  )
}

function DecisionSlide({ slide }: { slide: Slide }) {
  const claims = ["Fair comparisons built", "Warnings retained", "Claim stays conditional"]

  return (
    <SlideShell slide={slide} dark className="grid grid-cols-[0.9fr_1.1fr] items-center gap-10">
      <div className="relative z-10 flex flex-col gap-7">
        <DeckHeading slide={slide} light />
        <div className="flex flex-wrap gap-3">
          {claims.map((claim) => (
            <Badge key={claim} variant="secondary" className="px-4 py-1.5 text-sm">
              {claim}
            </Badge>
          ))}
        </div>
      </div>
      <Card className="relative z-10 overflow-hidden bg-white/95 shadow-2xl">
        <CardContent className="p-6">
          <img
            src="/images/diagrams/final_message_map.png"
            alt="Final message map"
            className="h-[64vh] w-full object-contain"
          />
        </CardContent>
      </Card>
    </SlideShell>
  )
}

function ChartFrame({ src, alt }: { src: string; alt: string }) {
  return (
    <Card className="h-[74vh] overflow-hidden shadow-2xl">
      <CardContent className="grid h-full place-items-center p-6">
        <img src={src} alt={alt} className="h-full w-full object-contain" />
      </CardContent>
    </Card>
  )
}

function MetricCard({ label, value }: { label: string; value: string }) {
  return (
    <Card>
      <CardHeader>
        <CardDescription>{label}</CardDescription>
        <CardTitle className="text-xl tracking-normal">{value}</CardTitle>
      </CardHeader>
    </Card>
  )
}

export default App
