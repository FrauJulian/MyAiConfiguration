# OG and Social Preview Images

## Required Meta Tags

Open Graph requires `og:title`, `og:type`, `og:url`, and `og:image`. Image dimensions and alternative text supplement those fields. Set the page type appropriately and keep the canonical page URL consistent.

```html
<meta property="og:title" content="Product guide" />
<meta property="og:type" content="article" />
<meta property="og:url" content="https://example.com/guides/product" />
<meta property="og:image" content="https://example.com/images/product-guide.jpg" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:image:alt" content="Product dashboard showing the project overview" />
```

Dimensions above describe the example asset, not a universal platform requirement. Verify current format, crop, and size requirements for the intended consumer. Add platform-specific card metadata through the existing framework integration when needed; confirm its current contract with `technical-research`.

## Delivery and Validation

- Put metadata in the delivered document head using the existing metadata API; avoid duplicate or conflicting tags.
- Use stable absolute HTTPS image URLs. Public previews must load without authentication and return the correct image content type. Keep private assets private.
- For recurring pages, reuse a template populated with page metadata. Prefer existing build-time generation or cache generated outputs; avoid adding a rendering service for a few static images.
- Check the actual response, metadata, crop, text readability, and target preview tool. Allow for consumer caching when validating updates. Social-preview metadata does not itself guarantee search ranking improvements.

Source: [Open Graph protocol](https://ogp.me/).
