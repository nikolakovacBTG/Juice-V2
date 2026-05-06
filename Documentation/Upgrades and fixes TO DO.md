# Upgrades and Fixes TO DO

> Active upgrade and fix plans for the Juice Demo project.
> Completed designs are moved to `Documentation/Done/`.

---

## SOP Gap: `/realistic-test` workflow needs a thorough rework

The SOP for writing realistic tests completely disregards our ability to use MCP to test things in a non-headless editor — things that would not be possible to test in a headless editor, such as using our own preview transport, simulating real use scenarios and user behaviours.

**Action:** Rework the `/realistic-test` workflow and write a new helper skill for it according to the `@create-quality-skill` skill.

