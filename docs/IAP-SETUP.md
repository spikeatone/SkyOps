# In-App Purchases — Go-Live Checklist

Getting Airline Architect Pro subscriptions live. The RevenueCat SDK is already
integrated and the app is coded to pick everything up once these are configured
— **no further code changes needed** beyond swapping the API key (step B7).

**Reusable values**
- **Bundle ID:** `Postmark-Digital.AirlineArchitect`
- **Products:** `monthly` ($5.99/mo) and `yearly` ($49.99/yr)
- **Entitlement:** `Airline Architect Pro` (must match the code in `Store.swift` **exactly** — spaces included)
- **API key lives in:** `AirlineArchitect/AirlineArchitect/Store.swift` → `static let apiKey`

> **Blocked until the Apple Developer Program membership is active.** App Store
> Connect access (agreements, products, sandbox testers) and RevenueCat's link
> to it all require the membership. Until then, playtest with the **DEV "Pro"
> toggle** (Network map, under the eye overlay) and the **Test Store key**
> (purchases run simulated).

---

## A. App Store Connect

### Prerequisites
- [ ] Apple Developer Program membership active ($99/yr).
- [ ] App record exists for bundle ID `Postmark-Digital.AirlineArchitect` (Apps → +).
- [ ] **Paid Applications Agreement signed** → *Business → Agreements, Tax, and Banking*. Sign the "Paid Apps" agreement and complete **banking + tax** info. **IAP does not work until this shows "Active"** — the #1 thing that blocks people.

### Subscription group + products (app → Monetization → Subscriptions)
- [ ] Create **one Subscription Group** (e.g. "Airline Architect Pro"). Both tiers go in the *same* group so they're mutually exclusive (monthly *or* yearly, with up/downgrade).
- [ ] Add subscription **`yearly`**: Product ID `yearly`, duration **1 Year**, price **$49.99**.
- [ ] Add subscription **`monthly`**: Product ID `monthly`, duration **1 Month**, price **$5.99**.
- [ ] For **each** subscription, fill required metadata (else it stays "Missing Metadata"):
  - [ ] Localized **display name** + **description** (English at minimum)
  - [ ] **Duration** + **price** (per-territory prices auto-fill from the base price)
  - [ ] A **review screenshot** of the paywall + **review notes**
- [ ] Set the **Subscription Group localization** (group display name shown at purchase).

### Sandbox testing account (Users and Access → Sandbox → Test Accounts)
- [ ] Create at least one **Sandbox tester** (an email not already used as an Apple ID).

> Products can sit in **"Ready to Submit"** and still work in **sandbox** — App Review approval isn't needed to test.

---

## B. RevenueCat (connects to App Store Connect)

- [ ] Open your RevenueCat project → the **iOS app** (bundle ID `Postmark-Digital.AirlineArchitect`).
- [ ] Give RevenueCat receipt access — do **one** of:
  - [ ] **In-App Purchase Key** (recommended): ASC → *Users and Access → Integrations → In-App Purchase* → generate → upload to RevenueCat, **or**
  - [ ] **App-Specific Shared Secret**: ASC → your app → *App Information* → generate → paste into RevenueCat.
- [ ] **Products**: add/import `monthly` and `yearly` (match the ASC Product IDs exactly).
- [ ] **Entitlement**: create identifier **`Airline Architect Pro`**; attach *both* products to it.
- [ ] **Offering**: create the "current" offering with two **packages** — **Annual → `yearly`**, **Monthly → `monthly`**. This is what the app loads for live prices.
- [ ] Copy the **production public SDK key** (`appl_…`) → replace the Test Store key in `Store.swift` (`static let apiKey`). ⚠️ The current `test_…` key gets the app **rejected in review** if shipped.

*(No RevenueCat dashboard Paywall needed — the custom in-app paywall is already wired to the offering.)*

---

## C. Test, then ship

- [ ] On a device/simulator, sign into the **Sandbox tester** (prompts at first purchase, or *Settings → App Store → Sandbox Account*).
- [ ] Buy each tier → confirm the app flips to Pro (caps lift; Finance shows "Airline Architect Pro"). Test **Restore Purchases** and **Manage subscription** (Customer Center).
- [ ] Submit: the **first** subscription must be submitted **together with an app version** in the same review. Attach the paywall screenshot + review notes.

---

## Common blockers
1. **Paid Apps agreement** not fully "Active" → purchases silently fail.
2. RevenueCat **entitlement name** not matching `Airline Architect Pro` exactly.
3. Forgetting to **swap the Test Store key** for the `appl_` key before submission.
4. **Product IDs are permanent** — `monthly`/`yearly` can't be renamed or reused later, so create them exactly as named.
