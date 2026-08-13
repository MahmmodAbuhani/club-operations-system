# Social preview provenance

[`social-preview.png`](social-preview.png) is a 1280 by 640 composition built from the authentic fictional-fixture capture in [`screenshots/03-equipment-fulfillment.png`](screenshots/03-equipment-fulfillment.png). The source screenshot comes from the fresh Docker workflow described in [`SCREENSHOTS.md`](SCREENSHOTS.md).

Regenerate the composition after installing the locked Node dependencies:

```bash
npm ci
npm run social-preview
```

[`scripts/build_social_preview.mjs`](../scripts/build_social_preview.mjs) embeds the source PNG into a fixed local HTML layout and captures it with the Playwright Chromium version in `package-lock.json`. The image identifies the system as local and the fixture as fictional. It does not depict a hosted service, production data, or an affiliation with a real club.

The repository contains the image file and its build path. Applying it to repository settings is a separate external action and is not performed by the build command.
