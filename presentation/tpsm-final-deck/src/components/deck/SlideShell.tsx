import type { ReactNode } from "react"
import { Separator } from "@/components/ui/separator"

type SlideShellProps = {
  title: string
  slideNumber: number
  children: ReactNode
  kicker?: string
}

export function SlideShell({ title, slideNumber, children, kicker }: SlideShellProps) {
  return (
    <div className="mx-auto flex h-full max-w-[1080px] flex-col px-12 py-10 text-left">
      <header className="flex items-start justify-between">
        <div className="flex max-w-[850px] flex-col gap-3">
          {kicker ? (
            <p className="text-sm font-medium uppercase tracking-[0.12em] text-primary">
              {kicker}
            </p>
          ) : null}
          <h2 className="text-[2.7rem] font-semibold leading-[1.05] tracking-normal text-foreground">
            {title}
          </h2>
        </div>
        <span className="text-sm tabular-nums text-muted-foreground">
          {slideNumber.toString().padStart(2, "0")}
        </span>
      </header>
      <Separator className="my-6" />
      <main className="min-h-0 flex-1">{children}</main>
    </div>
  )
}
