import { Plugin } from "@opencode/plugin/tui"
import { execSync } from "child_process"

export default Plugin.define({
  id: "auto-commit-push.tui",
  setup(context) {
    const runGitCommand = (cmd: string): string => {
      try {
        const dir = context.location?.directory ?? process.cwd()
        return execSync(cmd, { cwd: dir, encoding: "utf-8" }).trim()
      } catch (error) {
        return ""
      }
    }

    // Intercept session completion / idle event
    const stopSessionIdle = context.data.on("session.idle", async () => {
      const currentBranch = runGitCommand("git rev-parse --abbrev-ref HEAD")
      if (!currentBranch) return

      // Safeguard: Check AGENTS.md rule against pushing directly to main/master
      if (currentBranch === "main" || currentBranch === "master") {
        context.ui.toast.show({
          title: "Git Workflow Notice",
          message: `Direct pushes to ${currentBranch} are restricted by AGENTS.md rules. Create a feature branch and PR instead.`,
          variant: "warning",
          duration: 6000,
        })
        return
      }

      // Prompt user whether to push local branch to remote GitHub
      const confirmPush = await context.ui.dialog.confirm({
        title: "Push Branch to GitHub?",
        message: `Session completed and changes auto-committed locally on branch '${currentBranch}'. Would you like to push this branch to GitHub remote?`,
        label: { confirm: "Push to GitHub", cancel: "Keep Local Only" },
      })

      if (confirmPush) {
        try {
          context.ui.toast.show({
            title: "GitHub Push",
            message: `Pushing branch '${currentBranch}' to remote origin...`,
            variant: "info",
            duration: 3000,
          })

          execSync(`git push -u origin ${currentBranch}`, {
            cwd: context.location?.directory ?? process.cwd(),
            encoding: "utf-8",
          })

          context.ui.toast.show({
            title: "Push Successful",
            message: `Branch '${currentBranch}' successfully pushed to GitHub!`,
            variant: "success",
            duration: 5000,
          })
        } catch (err: any) {
          context.ui.toast.show({
            title: "Push Failed",
            message: `Failed to push branch to remote: ${err?.message || err}`,
            variant: "error",
            duration: 7000,
          })
        }
      }
    })

    return () => {
      stopSessionIdle()
    }
  },
})
