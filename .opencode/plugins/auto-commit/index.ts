import { Plugin } from "@opencode/plugin"
import { execSync } from "child_process"

export default Plugin.define({
  id: "auto-commit-push",
  async setup(ctx) {
    const controller = new AbortController()

    const runGitCommand = (cmd: string): string => {
      try {
        return execSync(cmd, { cwd: ctx.location.directory, encoding: "utf-8" }).trim()
      } catch (error) {
        console.error(`[auto-commit-push] Error executing '${cmd}':`, error)
        return ""
      }
    }

    const autoCommit = () => {
      const status = runGitCommand("git status --porcelain")
      if (!status) {
        return false // No uncommitted changes
      }

      const currentBranch = runGitCommand("git rev-parse --abbrev-ref HEAD") || "working-branch"
      console.log(`[auto-commit-push] Uncommitted changes detected. Auto-committing on branch '${currentBranch}'...`)

      runGitCommand("git add -A")
      runGitCommand(`git commit -m "chore(auto-commit): post-session save on ${currentBranch}"`)
      return true
    }

    void (async () => {
      for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
        if (event.type === "session.idle" || event.type === "session.closed") {
          const committed = autoCommit()
          if (committed) {
            console.log("[auto-commit-push] Post-session auto-commit completed successfully.")
          }
        }
      }
    })()

    return () => controller.abort()
  },
})
