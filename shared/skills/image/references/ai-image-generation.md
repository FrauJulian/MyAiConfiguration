# AI Image Generation

Generate original images from text prompts. The fastest way to create unique marketing visuals.

## Model Comparison

| Model | Best For | Text in Images | API | Cost |
|-------|----------|:-:|-----|------|
| **Gemini Image** (Google, "Nano Banana" / Nano Banana Pro) | All-around, editing, multi-image reference, text rendering | Good | [Gemini API](https://ai.google.dev/gemini-api/docs/image-generation) | Check [pricing](https://ai.google.dev/gemini-api/docs/pricing) |
| **Flux** (Black Forest Labs — Pro 1.1, Kontext, Dev, Schnell) | Photorealism, brand consistency, batch; Kontext for in-image editing | Limited | [BFL API](https://docs.bfl.ai/), Replicate, fal.ai | Check [pricing](https://docs.bfl.ai/quick_start/pricing) |
| **Ideogram 3.0** | Typography, branded graphics, accurate text rendering | Best | [Ideogram API](https://developer.ideogram.ai/) | Check [pricing](https://about.ideogram.ai/api-pricing) |
| **ChatGPT Images 2.0 / GPT Image** (OpenAI) | General purpose, ChatGPT integration, native editing | Good | [OpenAI API](https://platform.openai.com/docs/guides/image-generation) | Check [pricing](https://platform.openai.com/docs/pricing) |
| **Midjourney v7** | Artistic, high-aesthetic, art-directed visuals | Improved | No official API; Discord + Web | Subscription-based |
| **Recraft V3** | Vector + brand-consistent illustrations, design assets | Strong | [Recraft API](https://www.recraft.ai/docs) | Per-credit |
| **Stable Diffusion 3.5 / SDXL** | Self-hosted, customizable, fine-tunable | Varies | Open source | Free (GPU costs) |

**Note:** DALL-E 3 is fully deprecated. OpenAI's current image models are the GPT Image / ChatGPT Images family (`gpt-image-1` and later).

## When to Use Which

```
Need text/headlines in the image?
├── Yes → Ideogram 3.0 (best), Gemini (good), GPT Image / ChatGPT Images (decent)
└── No ↓

Need product/brand consistency across many images?
├── Yes → Flux (multi-image reference), Gemini Nano Banana Pro, Recraft V3
└── No ↓

Need to edit an existing image (in-place)?
├── Yes → Gemini (native editing), Flux Kontext, ChatGPT Images
└── No ↓

Need vector / illustrative brand assets?
├── Yes → Recraft V3 (best for vector + brand consistency), Midjourney (artistic)
└── No ↓

Need highest visual quality / art direction?
├── Yes → Flux Pro 1.1, Midjourney v7
└── No ↓

Need volume at low cost?
└── Flux Schnell, Gemini Flash, Stable Diffusion (self-hosted)
```

## Prompting Basics

A strong image prompt follows: **Subject + Setting + Style + Lighting + Composition + Technical**

```
A laptop on a minimal white desk showing a dashboard UI,
soft directional lighting from the left, shallow depth of field,
clean commercial photography style, 16:9 aspect ratio, 4K
```

**Common mistakes:**
- Too vague ("a business image") — add specific details
- Forgetting aspect ratio — always specify dimensions
- Requesting complex text — use overlays instead for anything beyond short headlines
- No style direction — "photorealistic," "flat illustration," "3D render"
