import type { ReactNode } from "react"
import { Separator } from "@/components/ui/separator"
import { Badge } from "@/components/ui/badge"

type SlideShellProps = {
  title: string
  slideNumber: number
  children: ReactNode
  kicker?: string
  /** Optional one-line lecture vocabulary for this slide */
  concepts?: string
  /** Short module-concept tags shown in the slide footer (e.g. "Hypothesis testing", "Population proportion"). */
  tags?: ReadonlyArray<string>
}

export function SlideShell({ title, slideNumber, children, kicker, concepts, tags }: SlideShellProps) {
  return (
    <div className="mx-auto flex h-full max-w-[1120px] flex-col px-10 py-8 text-left md:px-12 md:py-9">
      <header className="flex shrink-0 items-start justify-between gap-6">
        <div className="flex min-w-0 max-w-[880px] flex-col gap-2">
          {kicker ? (
            <p className="text-xs font-semibold uppercase tracking-[0.14em] text-primary md:text-sm">
              {kicker}
            </p>
          ) : null}
          <h2 className="text-[2.35rem] font-semibold leading-[1.08] tracking-tight text-foreground md:text-[2.65rem]">
            {title}
          </h2>
          {concepts ? (
            <p className="mt-1 max-w-[52rem] text-sm leading-snug text-muted-foreground md:text-base">
              {concepts}
            </p>
          ) : null}
        </div>
        <span className="shrink-0 pt-1 text-xs tabular-nums text-muted-foreground md:text-sm">
          {slideNumber.toString().padStart(2, "0")}
        </span>
      </header>
      <Separator className="my-5 shrink-0" />
      <main className="min-h-0 flex-1 overflow-hidden">{children}</main>
      {tags && tags.length > 0 ? (
        <footer className="mt-4 flex shrink-0 flex-wrap items-center gap-2 border-t border-border/60 pt-3">
          <span className="text-[0.65rem] font-semibold uppercase tracking-[0.14em] text-muted-foreground md:text-xs">
            Module concepts
          </span>
          {tags.map((tag) => (
            <Badge key={tag} variant="secondary" className="font-normal">
              {tag}
            </Badge>
          ))}
        </footer>
      ) : null}
    </div>
  )
}
