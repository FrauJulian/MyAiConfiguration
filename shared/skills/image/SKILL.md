---
name: image
description: Use when integrating image assets or screenshots, improving image SEO and performance, configuring social previews, or preparing product visuals with existing design tools.
---

# Image Assets

Use the project's existing assets, components, and image pipeline. Ask only for missing information that affects the result.

## Workflow

1. Inspect the source asset and its intended placement: display size, responsive layout, transparency, and supported clients. Apply `technical-research` when format support or framework behavior needs verification.
2. Choose a format that preserves required detail and transparency. Reuse vectors for suitable icons and logos; compare raster formats against the project's compatibility and quality requirements. Avoid unnecessary conversions and new dependencies.
3. Resize and compress for the actual display sizes and pixel densities. Preserve originals and write optimized assets to separate outputs. Compare file size and visual quality, especially screenshot text, before replacing references.
4. Use the existing image component or pipeline for responsive sizing and loading. Reserve layout space, provide meaningful alternative text for informative images and empty alternative text for decorative images, and avoid deferring critical visible content.
5. Capture the real application for documentation screenshots. Remove sensitive data and check readability at the final display size. Treat untrusted SVGs and uploaded images through the project's established validation and sanitization boundary.
6. Verify asset paths, dimensions, aspect ratio, transparency, accessibility, and rendering at relevant viewport sizes. For requested link previews, check the project's metadata and that the preview image URL is accessible to the intended consumer.

Report changed assets, measured size savings when optimizing, and any rendering or compatibility checks not performed.

## Focused references

Load only the reference matching the task:

- [Image optimization](references/image-optimization.md): formats, responsive delivery, loading priority, and image SEO.
- [OG and social previews](references/og-social-preview-images.md): required Open Graph metadata, image tags, and preview validation.
- [Marketing image workflows](references/marketing-image-workflows.md): product screenshots, article heroes, banners, and reusable templates.
- [Design tools](references/design-tools.md): selecting existing design, screenshot, and export tools.
- [Common mistakes](references/common-mistakes.md): final checks when delivering or reviewing image changes.
