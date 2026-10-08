# Common Mistakes

Check only issues relevant to the change:

- Oversized downloads or incorrect responsive candidates: inspect the resource actually selected at each target viewport.
- Lazy-loaded LCP image, excessive high-priority images, or late discovery: inspect the loading waterfall.
- Missing dimensions or wrong aspect ratio: check layout shifts and cropping.
- Blurry screenshot text, compression artifacts, or lost transparency: compare at final display size.
- Missing or keyword-stuffed alternative text; essential information available only inside an image: check accessibility.
- Broken, authenticated, blocked, or expired preview URLs; duplicate metadata or stale cached previews: inspect responses and the target preview.
- Sensitive data in screenshots, untrusted SVG markup, or overwritten originals: use sanitized inputs and preserve editable sources.
- Stale platform dimensions, unreadable banner text, or stretched variants: verify current requirements and inspect each export.
