# Image Optimization and SEO

- Start with measured transfer size, rendered dimensions, and the page's LCP element. Keep originals; compare optimized output at its actual display size.
- Use SVG for suitable vector assets, lossless formats for sharp UI text, and compare WebP/AVIF with existing raster formats for photographs. Choose against target-client support, transparency, quality, and measured size; avoid fixed quality or byte targets for every asset.
- Match `srcset` and `sizes` to the layout, or use the framework's existing image component. Set intrinsic `width` and `height` to reserve the correct aspect ratio.
- Lazy-load offscreen images. Keep the LCP image discoverable in initial HTML and eagerly loaded; consider `fetchpriority="high"` for that image, not every image.
- Use descriptive filenames, relevant surrounding text, and useful `alt` text without keyword stuffing. Decorative images need empty alternative text.
- For images intended for search, verify crawlable image URLs and standard image markup with a usable `src`. CSS backgrounds are not a substitute for indexable content images.
- Reuse existing transformation and caching infrastructure. Measure transferred bytes, rendering quality, LCP, and layout shifts after the change; distinguish lab results from real-user data.

References: [HTML images](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/img), [LCP optimization](https://web.dev/articles/optimize-lcp), [Google image SEO](https://developers.google.com/search/docs/appearance/google-images).
