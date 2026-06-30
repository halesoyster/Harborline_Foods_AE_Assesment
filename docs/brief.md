# Harborline Foods - Executive P&L Dashboard
### Engagement Brief

**Prepared for:** Dana Reyes (CFO) and the Harborline delivery team
**Prepared by:** Analytics Engineering, Blue Margin
**Status:** Week 3 - data conformance in progress
**Purpose:** Align on what we are building, why it stalled, and the path to a trustworthy dashboard.

---

## Situation

Harborline operates three brands across 40+ locations, brought together through two recent acquisitions. Because the brands grew up on different systems, the data still lives in three places that do not reconcile to each other: Toast POS (Brand A), Qu POS (Brand B), and Restaurant365 for group-wide financials. There is no single place to see how the business is performing across all brands - which is exactly the gap this engagement closes.

## What success looks like

Dana needs one executive view she can trust, with two priorities:

1. **Net Sales and Cost of Goods Sold by brand, location, and week**, including a rolling 4-week trend so she can see direction, not just a snapshot.
2. **A Prime Cost view** - labor plus COGS as a percentage of net sales - that she can filter to any brand or location. Prime cost is the number that tells a restaurant operator whether a location is actually healthy.

The deliverable is a Power BI dashboard backed by a conformed data model, with numbers that reconcile to the source systems.

## What we found (and why it stalled)

Reviewing the partially built model from the prior phase, we identified a specific, fixable root cause for the delay: **Brand B's locations were never mapped into the shared location dimension.** Qu identifies stores with one code format; the dimension only carried the Toast format. The result is that Brand B's sales could not be joined to the rest of the business, so any roll-up was silently incomplete. This is the single largest driver of the numbers looking off, and it is a mapping fix, not a rebuild.

The broader pattern is the same across systems: a reliable group-wide view requires the location dimension to recognize *every* source system's identifier for a location. We are conforming those keys so Toast, Qu, and R365 all resolve to one location.

## Approach

We are conforming the three sources into a single dimensional model, then exposing Dana's two views on top of it:

- **Conform the location dimension** so every system's store identifier resolves to one location. (Brand B mapping first, R365 alignment immediately after.)
- **Build one conformed net-sales measure** that handles each POS system's column differences and reconciles to source.
- **Layer COGS and labor from R365** and express Prime Cost as a clean, filterable percentage.
- **Validate before anything is client-facing** - reconcile totals, confirm no location is dropped, and prove Brand B is now fully represented.

Business logic lives in the data model, so the dashboard measures stay thin, fast, and maintainable by the next engineer.

## Scope

**In scope:** the conformed location dimension, conformed net sales across Toast and Qu, the COGS and Prime Cost logic from R365, and the two prioritized views with weekly and rolling-4-week trends.

**Out of scope for this phase:** menu-item / modifier-level analytics, labor scheduling optimization, and forecasting. Flagged as natural follow-ons once the foundation is trusted.

## Timeline

- **Now:** location dimension fix complete; conformed net sales validated against source.
- **Next:** R365 cost mapping conformed and Prime Cost wired in.
- **Then:** the two views assembled in Power BI and reconciled end to end before Dana sees them.

## Open questions to confirm with Dana

- Does Harborline report on a standard Monday-Sunday week or a 4-4-5 fiscal calendar? (Changes how every weekly number rolls up.)
- Confirm the authoritative source for the Qu store-to-location crosswalk.
- Confirm that Toast net sales is already net of discounts and voids, so our definitions line up exactly with how Finance already reads it.

## Stakeholders

- **Dana Reyes (CFO)** - primary stakeholder; consumes the executive views and owns the P&L definitions.
- **Blue Margin delivery team** - AE (build and validation) and CSM (client expectations and trade-offs).
