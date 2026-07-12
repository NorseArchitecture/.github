# Norse Architecture for .NET

**A fully composable, service-oriented architecture for the .NET space — opinionated where it counts, sovereign where it matters, and enforced by the compiler instead of the code review.**

---

## The pitch

Every .NET shop rebuilds the same platform, every time. Hosting, persistence, messaging, auth, validation, observability — the undifferentiated heavy lifting gets re-decided, re-implemented, and re-broken for every new service. The architecture lives in a wiki diagram that drifted from the code two sprints in, and the rules that matter are enforced by whoever happens to be reviewing the pull request that day.

Norse Architecture inverts that. The architecture *is* the substrate: a small set of repositories that declare the contracts, forge the primitives, implement the infrastructure, provide the host chassis, and orchestrate the whole. Your services conform to the contracts and ride the rails. Everything below your domain is decided once, enforced at build time, and done — so the only code you write is the code only you can write.

## Mythology markets. Functions operate. Docs explain.

The repositories are named for the Norse cosmos. The projects and namespaces inside them are named for exactly what they do. Open the organization and you tour the realms; open the solution and every project tells you its function before you read a line of it.

| Repository | The lore | The function |
|---|---|---|
| **[Asgard](https://github.com/NorseArchitecture/Asgard)** | Realm of the Æsir, whose laws bind gods and mortals alike | `Norse.Abstractions.*` — the contracts, marker types, and laws every realm must honor |
| **[Svartalfheim](https://github.com/NorseArchitecture/Svartalfheim)** | The dwarven forge where Mjölnir and Gleipnir were made | `Norse.Primitives.*` — domain value types, identifiers, result parsing, encryption: the unbreakable artifacts every realm carries |
| **[Urdarbrunnr](https://github.com/NorseArchitecture/Urdarbrunnr)** | The Well of Urd at Yggdrasil's roots, where the Norns draw water to sustain the tree and carve fate into its trunk as runes | `Norse.EntityFramework.*` — entity base types, DbContext foundations, conventions, value converters, and the migrations chassis: the record of all that has become |
| **[Midgard](https://github.com/NorseArchitecture/Midgard)** | Realm of mortals, where the law is lived | `Norse.Infrastructure.*` — concrete implementations of Asgard's contracts: persistence, caching, external integrations |
| **[Ratatoskr](https://github.com/NorseArchitecture/Ratatoskr)** | The sly squirrel that races up and down Yggdrasil, carrying slander and secrets between the eagle at the crown and Níðhöggr at the roots — the original message broker | `Norse.NServiceBus.*` — NServiceBus endpoint configuration, saga infrastructure, message conventions, and transport wiring: Asgard declares the messaging surface; Ratatoskr carries it |
| **[Yggdrasil](https://github.com/NorseArchitecture/Yggdrasil)** | The World Tree that binds the nine realms | `Norse.Hosting.*` — the web, worker, and migration service chassis every realm runs on |
| **[Himinbjörg](https://github.com/NorseArchitecture/Himinbjorg)** | Heimdall's hall at the head of Bifröst, where the watchman keeps the record of all who may cross | `Norse.Identity.*` — backend-only EF persistence for ASP.NET Identity and OpenIddict: the record of who is who, sealed server-side, never crossing to WASM or MAUI |
| **[Heimdall](https://github.com/NorseArchitecture/Heimdall)** | The ever-watchful guardian of Bifröst, keenest of sight and hearing, who alone decides who may cross | `Norse.AuthN.*` — the authn story riding on Himinbjörg's identity record: login, register, forgot-password, 2FA setup, recovery, and reset, uniform across Blazor Server, WASM, and MAUI, with the backing gRPC service |
| **[Mímisbrunnr](https://github.com/NorseArchitecture/Mimisbrunnr)** | The well of wisdom at Yggdrasil's roots, guarded by Mímir, where Odin traded an eye for a single drink of it | `Norse.ReferenceData.Data` — entities, view models, TSV seeders, and migrations for canonical reference data: ISO country/currency codes, IANA time zones |
| **[Mímir](https://github.com/NorseArchitecture/Mimir)** | Beheaded in the Æsir-Vanir war, yet still carried and consulted by Odin for counsel wherever his head was taken | `Norse.ReferenceData.Components` / `.Web.Server` / `.Worker` — the serving layer on Mímisbrunnr: Blazor components, gRPC service host, and the background worker that keeps reference data current |
| **[Naglfar](https://github.com/NorseArchitecture/Naglfar)** | The vast ship built from the nails of the dead — launched at Ragnarök to carry the fight, purpose-built to be spent when the battle is won | `Norse.DesignSystem.*` — the token pipeline: design tokens, spacing scale, radii, and typography, forged seaworthy enough to carry every product UI until the vision is realized. npm-only, no .NET |
| **[Bragi](https://github.com/NorseArchitecture/Bragi)** | The skaldic god of poetry, keeper of every tale worth telling | `Norse.DesignSystem.Stories` — the content-only Razor Class Library of component story pages that Yggdrasil's BlazingStory catalog hosts. Bragi doesn't build the ship; he sings of everything aboard it |
| **[Bifröst](https://github.com/NorseArchitecture/Bifrost)** | The rainbow bridge between the realms, watched over by Heimdall | `Norse.Orchestration.*` — the .NET Aspire composition layer that connects services, databases, queues, and configuration into one running platform |
| **[Glitnir](https://github.com/NorseArchitecture/Glitnir)** | The shining hall of judgment — gold pillars, silver roof — where every suit is settled | The design court — specs, plans, and proof-of-concept verdicts: the architecture is argued to convergence here before code renders the verdict |
| **[Ginnungagap](https://github.com/NorseArchitecture/.github)** | The primordial void — the yawning gap before creation, from which fire and frost met to kindle the cosmos | The org infrastructure: community-health files, reusable GitHub Actions workflows, config scatter, and the Law of the Æsir — everything that exists before and beneath the realms. GitHub enforces the repository name `.github`; the lore name is Ginnungagap. |

This split is deliberate, and it is the cure for the oldest disease in software: **names that drift**. A namespace is operational truth — the compiler enforces it, so it cannot rot. A myth is a story — stories don't need refactoring. The hype lives at the front door; the function lives in the code; the docs connect the two. Three jobs, never crossed.

## Composable means composable

The substrate stacks in one direction, and your code sits on top of all of it:

1. **Asgard declares the law** — contracts and abstractions, with no implementations to leak.
2. **Svartalfheim forges the artifacts** — primitives hardened below the domain, so they compose any domain you define above them.
3. **Urdarbrunnr keeps the record** — the Entity Framework foundation: entity base types, DbContext foundations, conventions, value converters, and the migrations chassis, so persistence starts lawful instead of becoming lawful.
4. **Midgard does the work** — the law, implemented: every infrastructure decision made once, correctly.
5. **Ratatoskr carries the messages** — NServiceBus endpoint configuration, saga infrastructure, and transport wiring, so the Æsir declare the messaging surface and every realm picks its own courier.
6. **Yggdrasil carries the load** — a hardened chassis for web, worker, and migration services, so a new service starts at "write your domain," not "configure your host."
7. **Himinbjörg keeps the roll call** — EF persistence for ASP.NET Identity and OpenIddict, sealed server-side: the record of who is known, on which every realm that defers to Heimdall's judgment stands.
8. **Heimdall guards the gate** — login, register, forgot-password, 2FA setup, recovery, and reset, enforced identically across Blazor Server, WASM, and MAUI, with the backing gRPC service, so the authn story is declared once and crossed nowhere it isn't permitted.
9. **Mímisbrunnr holds what is known** — canonical reference data (ISO country/currency codes, IANA time zones), entities and migrations only, so every realm draws from one well instead of redefining external standards for itself.
10. **Mímir answers for it** — Blazor components, gRPC service host, and a background worker that keeps Mímisbrunnr's data current, so consuming reference data is a query, not a research project.
11. **Bifröst bridges it together** — one orchestration layer composing every resource, from first `dotnet run` on a laptop to deployment.

**Naglfar stands apart** — no substrate dependencies, no layer to slot into: design tokens and the spacing and typography foundations forged from unglamorous remnants into something seaworthy enough to carry every product UI, purpose-built to be discarded when the vision it scaffolds is realized. **Bragi rides on every realm that publishes Blazor components** — today that's Asgard's `Abstractions.Components` (the headless primitives); `AuthN.Components.FluentUI` (Heimdall) and `ReferenceData.Components.FluentUI` (Mimir) join the same way as soon as those realms ship one, no re-architecture required. Bragi ships no runnable app of its own; Yggdrasil hosts the catalog Bragi's stories describe.

Your services live under your own root — `{Company}.{Context}.*` — and the platform neither knows nor cares what you build there. Conform to `Norse.Abstractions`, ride the rails, and your domain is sovereign: your namespaces, your models, your business.

**The proof is Billing.** Picture three companies on the substrate — an insurance MGA, an energy retailer, a logistics operation — each with a context named Billing. Insurance Billing accretes earned premium day after day on risk. Energy Billing coordinates four distinct utility-billing models. Logistics Billing invoices orders flowing in from across the globe. Same name, three completely different animals, **zero shared code** between them — and the platform hosts all three identically. That gap isn't a limitation. That gap *is* the design.

## Opinions, enforced

Norse Architecture is built around the **pit of success**: the easy path and the correct path are the same path, and the wrong path doesn't compile.

- **Compile-time over runtime.** Source generators and Roslyn analyzers over reflection and convention-scanning. If the architecture has a rule, the build enforces it — not the reviewer, not the wiki, not tribal memory.
- **Fail loudly.** No silent fallbacks, no default-swallowed errors. If it can fail, it fails immediately and visibly.
- **Smart about one thing.** Every component is the expert and source of truth for exactly one subject, and deliberately dumb about everything else.
- **Warnings are errors.** Ratcheted at build time, everywhere, on purpose.
- **Naming is a deliberate act.** Names describe the role, never the mechanism — and the structure above exists so that no load-bearing name can ever drift.

## The crooked path

Most architectures show you the cathedral and hide the scaffolding accidents. We publish ours. Every reversal, wrong turn, and bad call made designing this platform is recorded and shipped alongside the result — what was believed, why it was wrong, how it surfaced, and what it taught. The full ledger is public in [Glitnir](https://github.com/NorseArchitecture/Glitnir), the design court, where every spec is argued to convergence before code renders the verdict. The clean architecture is the verdict; the crooked path is the trial. An architecture that claims it's better to be *wrong cheaply and visibly* than *wrong expensively and silently* has to hold itself to that standard first.

## Status

Norse Architecture is built spec-first: designs are argued, reconciled, and judged before code renders the verdict. The realms above are landing now, in dependency order — laws before implementations, implementations before hosts. Watch the repositories, read the lore, and check back as the cosmos fills in.

---

*Built on modern .NET. Forged for everything after.*
