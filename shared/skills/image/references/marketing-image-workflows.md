# Marketing Image Workflows

## Blog & Article Hero Images

The image at the top of every post. Sets tone, improves shareability, required for OG/social previews.

1. **Define the concept** — what visual metaphor represents the topic?
2. **Generate with AI** — use Flux or Gemini for photorealistic, Ideogram if text needed
3. **Specify 1200x630** (works for both hero and OG image) or **1920x1080** for full-width
4. **Optimize** — compress to <200KB, serve as WebP with JPEG fallback

**Prompt pattern:**
```
[Visual metaphor for topic], clean modern style,
bright natural lighting, shallow depth of field,
professional blog header aesthetic, 1200x630
```

## Social Media Graphics

Platform-specific images for organic posts.

| Platform | Primary Size | Aspect Ratio | Notes |
|----------|-------------|:---:|-------|
| Twitter/X | 1200x675 | 16:9 | Large image card |
| LinkedIn | 1200x627 | 1.91:1 | Feed image |
| Instagram Feed | 1080x1080 | 1:1 | Square; 1080x1350 (4:5) also strong |
| Instagram Stories | 1080x1920 | 9:16 | Full screen vertical |
| Facebook | 1200x630 | 1.91:1 | Link share image |

**Workflow:**
1. Create the hero concept at highest resolution needed
2. Use Canva Magic Resize or manual crop for platform variants
3. Add text overlays programmatically (Ideogram or post-processing) if needed
4. Export at platform-specific dimensions

## Product Mockups & Screenshots

Showcase your product UI in context. AI models hallucinate UI — don't use them for this.

1. **Capture real screenshots** of your product at 2x resolution
2. **Frame in device mockups** — use browser frame, laptop, or phone templates
3. **Add context** — callout arrows, feature labels, before/after comparisons
4. **Annotate with code** — Hyperframes or HTML/CSS for programmatic overlays

**Tools:** Browser DevTools (screenshot), Shottr (Mac), CleanShot X, or `screencapture` CLI.

## Profile & Listing Banners

Banners for profiles, directory listings, and marketplace pages. Often the first visual impression.

| Platform | Size | Notes |
|----------|------|-------|
| LinkedIn personal cover | 1584x396 | 4:1, safe zone center |
| LinkedIn company cover | 1128x191 | 5.9:1; LinkedIn recommends up to 4200x700 |
| Twitter/X header | 1500x500 | 3:1, partially obscured by avatar |
| Product Hunt gallery | 1270x760 | 5:3, up to 6 images |
| G2 profile | 1280x720 | 16:9, product screenshots preferred |
| GitHub social preview | 1280x640 | 2:1, shows in link cards |
| App Store screenshots | Varies by device | Check current platform specifications |
| Google Play feature graphic | 1024x500 | ~2:1, required for store listing |

**Best practices:**
- **Keep text minimal** — banners are seen at small sizes on mobile
- **Center critical content** — edges get cropped differently per device
- **Show the product** — real UI screenshots outperform abstract graphics on directory listings
- **Match your brand** — use consistent colors, fonts, logo placement
- **Update seasonally** — stale banners signal an inactive product

**Workflow:**
1. Pick the platform(s) and note exact dimensions
2. For directories (Product Hunt, G2): use real product screenshots with light annotation
3. For profiles (LinkedIn, Twitter): use brand colors + tagline + optional product shot
4. Generate with Canva/Figma templates or Ideogram (if text-heavy)
5. Test at actual display size — zoom out to check readability

## Brand Assets

Logos, icons, and illustrations. AI generation has limits here.

| Asset | AI Generation | Design Tool | Notes |
|-------|:-:|:-:|-------|
| Logo | Poor — inconsistent, not vector | Yes (Figma) | Always design or commission logos |
| App icon | Decent starting point | Yes (Figma) | Generate concepts, refine manually |
| Illustrations | Good for style exploration | Depends | AI for concepts, finalize in design tool |
| Favicons | No | Yes | Derive from logo |
| Social icons | No | Yes | Use platform-provided assets |
