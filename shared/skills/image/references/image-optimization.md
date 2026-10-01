# Image Optimization

Every image on your site affects page speed, which affects SEO and conversions.

## Format Guide

| Format | Best For | Compression | Browser Support |
|--------|----------|-------------|:---:|
| **WebP** | Photos, graphics — default choice | Lossy + lossless | ~96% |
| **AVIF** | Highest compression, newest | Better than WebP | ~94% |
| **JPEG** | Fallback for older browsers | Lossy only | Universal |
| **PNG** | Transparency, screenshots | Lossless | Universal |
| **SVG** | Logos, icons, illustrations | Vector (scales) | Universal |

## Optimization Checklist

- [ ] **Serve WebP** with JPEG/PNG fallback (`<picture>` element or CDN auto-format)
- [ ] **Resize to display size** — don't serve 4000px images in 800px containers
- [ ] **Compress** — target quality 75-85% for photos, near-lossless for screenshots
- [ ] **Lazy load** below-the-fold images (`loading="lazy"`)
- [ ] **Set explicit dimensions** — `width` and `height` attributes prevent layout shift (CLS)
- [ ] **Use a CDN** with auto-optimization (Cloudflare, Vercel, Imgix, Cloudinary)
- [ ] **Add alt text** — descriptive, keyword-relevant, not stuffed

## Quick Optimization Commands

```bash
# Convert to WebP (using cwebp)
cwebp -q 80 input.png -o output.webp

# Batch convert with ImageMagick
mogrify -format webp -quality 80 *.png

# Optimize JPEG (using jpegoptim)
jpegoptim --max=80 --strip-all *.jpg

# Check image sizes on a page
curl -s https://yoursite.com | grep -oP 'src="[^"]+\.(jpg|png|webp)"' | head -20
```
