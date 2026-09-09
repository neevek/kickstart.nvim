# Reviewing changes

Use Diffview for reviewing several files together. It opens a separate tab with a changed-file tree on the left and synchronized before/after buffers. The plugin loads only when a review command or shortcut is used.

| Shortcut | View |
| --- | --- |
| `,gv` | Working changes, with unstaged and staged sections |
| `,gV` | Staged changes against HEAD |
| `,gh` | Current file's commit history |
| `,gH` | Repository commit history |

In a review, select a file with `j` / `k` and Enter. Tab / Shift-Tab switches files; `]c` / `[c` moves between hunks. `,e` focuses the changed-file panel and `,b` toggles it. Press `q` from the diff buffers or file panel to close the review and return to the previous tab. `g?` shows the available mappings. In the file panel, `s` stages/unstages a selected file and `R` refreshes the list.

Useful comparisons:

```vim
:DiffviewOpen HEAD
:DiffviewOpen HEAD^!
:DiffviewOpen origin/master...HEAD
:DiffviewOpen -- native/platform/common/src/gl
```

`HEAD` shows tracked working-tree changes against the last commit; `HEAD^!` reviews the last commit; `origin/master...HEAD` reviews the current branch from its merge base with master. Use the base branch appropriate to the repository. These commands use local Git refs; fetch separately when you need current remote refs.

For small checks while editing, the existing Gitsigns mappings remain useful: `,hd` compares the current file against the index, `,hD` compares it against the last commit, and `]c` / `[c` moves between hunks. `,gd` keeps the existing Snacks hunk picker; `,gs` opens Git status. Neither Diffview nor these shortcuts automatically commits or pushes changes.

Apollo's `core/u3player_core` is a separate Git repository. Open a review from that directory to inspect its changes; the main repository's review does not include them.

Diffview is pinned to `4516612` and its [upstream usage documentation](https://github.com/sindrets/diffview.nvim#usage) describes revision ranges, file history and merge-conflict views. Close review tabs with `q` before saving an editing session.
