# AESKAR fork notes

## What this fork is

This is the AESKAR AB fork of [Campsite](https://github.com/campsite/campsite), kept at `aeskar/campsite`. It is used only internally by AESKAR staff, self-hosted on our own infrastructure.

The code is under the Creative Commons Attribution-NonCommercial 4.0 International license (see `LICENSE`). The licensors state in that file that self-hosting the software for internal purposes counts as non-commercial use. We rely on that note: the fork is not offered to third parties and is not part of any product or service we sell.

The `upstream` remote points to `campsite/campsite`. Upstream is provided as-is and is not actively maintained, so we do not expect regular merges from it.

## Design

The architecture, hostnames, hosting and decisions live in the infra repository:
[Campsite design](https://github.com/aeskar/aeskar-infra/blob/main/docs/superpowers/specs/2026-11-05-campsite-design.md).

## Replacements

Some hosted services that upstream depends on are replaced with self-hostable or AESKAR-owned ones:

| Upstream dependency | Replacement in this fork |
| --- | --- |
| Pusher (realtime) | Soketi, a Pusher-compatible server |
| Imgix (image CDN fed from S3) | self-hosted imgproxy |
| OpenAI (AI summaries, `api/lib/llm.rb`) | Anthropic API (key from `ANTHROPIC_API_KEY`, model from `LLM_MODEL`) |
| Postmark (mail) | Amazon SES |

Calls (100ms), Slack, Linear, Figma, Zapier, Cal.com, Plain, Vercel revalidate and the data exporter stay unconfigured. Boot must not fail when their credentials are missing.

## Secrets

Nothing secret is ever committed to this repository, which is public. Example files hold placeholders only. Real values are injected at runtime from the infrastructure side (environment variables first, Rails credentials as fallback). Generated public keys, such as the VAPID public key or the Soketi app key, may be committed. Private halves may not.

## Running `selfhost/`

To be written in Task 6 of the foundation plan. This section is a placeholder until then.
