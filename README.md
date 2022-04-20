```bash
# Show historical monthly issue and PR totals for the last 6 months
bash -c \
  "$(curl -fsSL https://sideshowbarker.github.io/github-monthly-issue-totals/gh-totals.sh)" "" 6
```

Example output:

```
 https://github.com/mdn/content
┌─────────────┬────────────────────┐
│    Issues   │         PRs        │
├──────┬──────┼──────┬──────┬──────┤
│ Clsd │ Opnd │ Mrgd │ Clsd │ Opnd │             Month range
├──────┼──────┼──────┼──────┼──────┼─────────────────────────────────────────┐
│  185 │  219 │  405 │   38 │  440 │ Oct 21 – Nov 20 2021, ending 5mos ago   │
│  200 │  217 │  396 │   38 │  416 │ Nov 21 – Dec 20 2021, ending 4mos ago   │
│  253 │  246 │  523 │   50 │  570 │ Dec 21 – Jan 20 2022, ending 3mos ago   │
│  193 │  211 │  542 │   96 │  653 │ Jan 21 – Feb 20 2022, ending 2mos ago   │
│  219 │  264 │  515 │   40 │  587 │ Feb 21 – Mar 20 2022, ending 1mo ago    │
│  250 │  261 │  677 │   61 │  733 │ Mar 21 – Apr 20 2022, ending today      │
└──────┴──────┴──────┴──────┴──────┴─────────────────────────────────────────┘
 For the last 6 months:
     216 issues closed per month on average.
     236 issues opened per month on average.
     509 PRs merged per month on average.
      53 PRs closed (unmerged) per month on average.
     566 PRs opened per month on average.
 Open issues: Increased by 118 in 5 months. Currently 670.
 Open PRs: Increased by 18 in 5 months. Currently 90.
```

## Description

This tool, run locally in a clone of a GitHub repo, and given a number of months _N_ as an argument, uses the GitHub API to show — for the history of the last _N_ months — a month-by-month listing of:

- the total number issues closed and opened and for each month
- the total number of PRs merged, closed, and opened for each month

The tools also shows, for the history of the given _N_ months:

- the average number of issues closed and opened per month over the given history
- the average number of PRs merged, closed, and opened per month over the given history
- the total increase or decrease in the number of open issues and PRs over the given history

## Notes

- The month ranges shown are for logical months based on the current date (today) rather than calendar months. That is, each “month” range shown ends on the same calendar day as as today — rather than being a calendar month starting on the 1st of a given month and ending on the 30th, 31st, 28th, or 29th.

- Unless you have either `GITHUB_TOKEN` or `GH_TOKEN` set in your environment, running this tool will likely cause you to quickly exceed the GitHub API rate limits for requests, and start getting 403 error responses.

- Even with `GITHUB_TOKEN` or `GH_TOKEN` set, the tool runs relatively slowly, due to some throttling added to avoid hitting the GitHub API rate limits for (authenticated) requests.

- If the clone has a remote named `upstream` defined, the tool uses that remote; otherwise it uses `origin`.
