# The SIGNAL Framework
### A data storytelling method

Built from: Humm's P.A.S.T. (scene craft), Wiebe's psychological principles (structure), Knaflic's *Storytelling with Data* (audience-first, decluttering), Dykes' data–narrative–visuals triad, Minto's Pyramid Principle / SCQA (executive logic), and the McCandless Method (chart-level delivery).

The premise: **most analysis fails not because the math is wrong, but because it stays at the helicopter view.** SIGNAL forces you down into the trench where the finding actually lives, then back up to a decision.

---

## The six moves

### S — Setting
*Establish before you explain.*

One slide, ten seconds: who this is about, what window, what decision is on the table. Not "Q3 Churn Analysis" — "We're deciding whether to keep the new onboarding flow. This is what happened to the 400 accounts that went through it in March."

- Borrowed from: Wiebe's establishing shot, SCQA's *Situation*, Humm's *Place*.
- Test: could someone who walked in late orient in one breath?

### I — Interruption
*Break the pattern. Open the loop.*

Something in the data violated the expected pattern. Say that, and don't resolve it yet. "Revenue was flat — but the two halves of that number moved in opposite directions."

- Borrowed from: predictive processing, SCQA's *Complication*.
- Caution: this is a delay of seconds, not minutes. With senior audiences, state the headline, then open the loop underneath it. Suspense is not a substitute for an answer.

### G — Guilty party
*Name a mechanism, not a metric.*

"Churn" is not a villain — it's a scoreboard. The villain is specific, concrete, and actively doing harm: *the third onboarding email points to a settings page that 404s on mobile.* Audiences can't act against an aggregate. They can act against a broken page.

- Borrowed from: Wiebe's villain, root-cause analysis.
- Test: is your villain something a named team could fix on Monday?

### N — Narrow in
*Zoom into one scene.*

Pick the single strongest piece of evidence and go deep on it instead of showing six charts shallowly. This is where P.A.S.T. operates at chart level:

| | In a story | In your analysis |
|---|---|---|
| **Place** | State the location | Annotate the exact cohort, week, or point on the chart |
| **Action** | Lead with a verb | Chart title is a sentence with a verb: "Signups leaked out before first login" |
| **Speech** | Exact dialogue | A verbatim support ticket, interview line, or rep quote |
| **Thought** | Raw inner reaction | "I assumed seasonality — then I saw it in three unrelated regions" |

Speech and Thought are the two most analysts skip, and they carry most of the persuasion. One real customer sentence beside the number outperforms a fourth chart.

### A — Ante
*Quantify the cost of doing nothing.*

Agitation, but numerate. What does this cost per month if untouched, and why does it compound? Attach a magnitude and a rate, and be honest about the interval around both.

- Borrowed from: Problem–Agitation–Solution.

### L — Landing
*Return, twist, and ask.*

Reopen the question from the Setting, answer it, and add the one thing you didn't expect going in. Then make an explicit ask: the decision, the owner, the date. A data story that ends in admiration rather than a decision has failed.

- Borrowed from: bookending, Minto's pyramid.

---

## Three governing rules

**1. Chekhov's gun — cut ruthlessly.**
Every chart that doesn't advance the argument opens a loop you won't close, and someone will spend ten minutes on it. If a slide can't name which SIGNAL move it serves, it goes in the appendix.

**2. Drama may not outrun the evidence.**
Sugarcoating works — wrap the medicine in conflict — but the confidence in your telling must match the confidence in your data. If the effect is noisy, the story is allowed to be noisy. Overclaiming survives one meeting and costs you the next five.

**3. Invent nothing on the evidence side.**
Storytelling coaches permit recreating dialogue you don't remember exactly. That rule does not cross over. Structure, framing, and how you narrate your own reasoning are yours to shape. Quotes, numbers, and mechanisms are not.

---

## The prose layer

SIGNAL sets what goes where. This layer sets how the sentences move once you're inside a move — it matters most in written reports and commentary fields, where no presenter is there to carry the argument.

The underlying mechanic: each clause has a **topic position** (the doorstep — familiar information, what the reader already holds) and a **comment position** (the room — the new information). Control which is which and prose becomes readable almost automatically.

### Linking — for established causal chains

Each clause opens with something from the previous clause's comment, creating forward momentum. This is the natural shape of a mechanism explanation:

> Traffic fell nine percent in March. The drop concentrated almost entirely in mobile. Mobile users were the only cohort routed to the new checkout, and that checkout had added a verification step.

**Use it only when you have actually established the mechanism.** The linking pattern *manufactures the feeling of causation* — readers experience the chain as a causal claim even when no causal word appears. That's exactly what you want for a confirmed chain, and quietly dishonest for a correlation you haven't explained. This is the single most consequential sentence-level choice in analytical writing.

### Anchoring — for associations you can't yet explain

Same topic held across clauses; new details accumulate in the comment position. The pattern feels slightly stagnant, and here that's a feature — it holds one subject still and reports facts about it instead of implying flow.

> Enterprise churn rose to 4.1% in Q3. It rose across all three regions, not just North America. It showed no relationship to contract size, and it began two weeks before the pricing change shipped.

Nothing there implies a mechanism, because there isn't one yet. Anchoring is the honest default for the **Interruption** move, where you've found a pattern break but haven't diagnosed it. Switch to linking once you reach **Guilty party** and the mechanism is real.

### Taxonomic — for findings that decompose

Name the umbrella concept, then unpack its parts, even though each part is a different topic. This is the right shape for most segment and driver analyses, where the finding splits into categories rather than a sequence.

> Three things drove the increase. Onboarding failures accounted for roughly half. Billing friction added another quarter. The remainder was ordinary voluntary churn, unchanged year over year.

### Theme preview — for the opening

The first sentence acts as tour guide, announcing the strands to be developed in order. This *is* the Setting move written out, and it's what makes a long memo navigable.

> This memo covers what happened to enterprise retention in Q3, why the onboarding flow is the likeliest cause, what continuing costs us, and what I recommend we change before renewals open in November.

Then develop each strand in that order, without reordering. A preview whose sequence doesn't match the body is worse than no preview.

### Pattern by move

| SIGNAL move | Default pattern | Why |
|---|---|---|
| Setting | Theme preview | Announces the strands |
| Interruption | Anchoring | Pattern break, no mechanism claimed yet |
| Guilty party | Linking | Mechanism established — chain it |
| Narrow in | Anchoring, then linking | Hold the scene still, then walk the causal step |
| Ante | Taxonomic | Costs usually decompose into categories |
| Landing | Theme preview, echoed | Callback to the opening strands, resolved |

Mix freely, and note the patterns work at every resolution — clause, paragraph, and section. A taxonomic paragraph can sit inside a linked section.

## Putting it in the tools

**First, a distinction that matters.** SIGNAL is a narrative framework. Narrative is linear, authored, and consumed once. A dashboard is non-linear, self-directed, and consumed repeatedly. Forcing a full story arc into a monitoring dashboard produces something that's annoying by the fortieth visit. So:

| Artifact | How much of SIGNAL applies |
|---|---|
| PowerPoint / readout deck | All six moves, in order |
| Written report / memo | All six, but inverted — Landing near the top |
| Analytical or "explainer" dashboard | S, G, N — structure and framing, not suspense |
| Monitoring / ops dashboard | S only, plus the Chekhov's gun rule |

---

### PowerPoint (readout deck)

The cleanest fit. One move per section:

- **S** — Title slide states the decision, not the topic. Add a subtitle: scope, window, and the question being answered.
- **I** — One slide, one chart, showing the pattern break. No explanation yet.
- **G** — The mechanism slide. This is your diagnostic chart plus a plain-language sentence naming the cause.
- **N** — Your single best piece of evidence, given a full slide: annotated chart, a verbatim quote in the margin, and a line of your own reasoning in the speaker notes (say it, don't print it).
- **A** — Cost of inaction. A number with a range on it.
- **L** — Recommendation, owner, date. Callback to the title-slide question.

Formatting rules that carry the framework: **every slide title is a full sentence with a verb.** "Enterprise churn doubled after the March pricing change," not "Churn by Segment." If you can read only the titles top to bottom and get the argument, the deck works. Everything else goes to appendix.

### Written report or memo

Same content, inverted for readers who skim. Minto order: answer first.

1. **Bottom line** (this is your Landing, moved to the top) — the finding and the ask, in three sentences.
2. **Setting** — scope, window, method, in a short paragraph.
3. **Guilty party + Narrow in** — the body. This is where P.A.S.T. lives: one section per finding, each opening with a verb-sentence heading, each containing one annotated exhibit and, where you have it, a real quote.
4. **Ante** — implications and cost of inaction.
5. Appendix — methodology, caveats, everything Chekhov's gun cut from the body.

The Interruption move mostly drops out. Readers control their own pace; withholding is just friction on the page.

### Power BI

Think in three page types, and don't mix them:

- **Landing page = Setting.** A title that states the question, a date-range and scope indicator that's always visible, and 3–5 KPI cards with comparison context (vs. target, vs. prior period) — never a bare number.
- **Diagnostic page = Guilty party.** Decomposition tree and Key Influencers are literally villain-hunting tools; that's their job. Point them at the metric from the landing page. Use drillthrough so the path from "what" to "why" is a click, not a hunt.
- **Detail page = Narrow in.** Row-level table, filtered by the drillthrough context, so someone can land on the actual accounts or tickets.

Where the story gets in: **dynamic titles.** A DAX measure that writes the verb-sentence for you — `"Churn rose " & FORMAT([ChurnDelta],"0.0%") & " vs last quarter"` — is the single highest-leverage move, because the chart narrates itself as filters change. Smart narrative visuals do a weaker version of this automatically; hand-written measures are better. Bookmarks can create a guided sequence if you genuinely need a linear walkthrough inside the tool.

Chekhov's gun in BI is a discipline problem: every extra visual is a question someone will ask you about. If nobody has ever made a decision from a card, delete it.

### Tableau

- **Dashboards** get the same three-tier structure as Power BI: overview → diagnostic → detail, connected by actions rather than drillthrough.
- **Story Points** are the one place a BI tool actually does linear narrative. If you need the full six moves inside Tableau, this is where they go — one story point per move, captions written as verb-sentences.
- **Annotations and reference lines** are your Narrow-in mechanism. Mark the specific week the change happened and label it in plain words. An unannotated line chart is a helicopter view by default.
- Use a dynamic title calculation the same way as DAX above, and use tooltips for the "Speech" layer — a representative verbatim on hover, where space doesn't permit it on the canvas.

### What to do about Speech and Thought in a tool

These are the two P.A.S.T. elements with no native home in BI, which is exactly why dashboards feel bloodless.

- **Speech** — a text box or tooltip carrying one representative verbatim, refreshed monthly. Not decoration; it's the qualitative evidence for the mechanism your chart implies.
- **Thought** — belongs in the commentary field, the email that ships the refresh, or the speaker notes. Never on the canvas of a recurring dashboard, where it goes stale and becomes a liability.

---

## Pre-flight checklist

- [ ] Can a latecomer orient in one breath? (S)
- [ ] Is there a pattern break, stated plainly? (I)
- [ ] Is the villain a fixable mechanism with an owner? (G)
- [ ] Does my strongest chart have a place, a verb, a voice, and an honest thought? (N)
- [ ] Is the cost of inaction quantified with its uncertainty? (A)
- [ ] Does it end in a decision, an owner, and a date? (L)
- [ ] Have I cut every chart that serves none of the above?
- [ ] Where I used the linking pattern, is the causal chain actually established — or am I letting sentence flow imply a mechanism I haven't proven?
- [ ] Does my opening preview match the order of the body?
