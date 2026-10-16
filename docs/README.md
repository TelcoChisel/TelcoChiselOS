# Documentation portal moved

The Nuxt site for **https://telcochisel.com** lives in a dedicated repository:

**https://github.com/TelcoChisel/website**

Canonical tool catalog SoT for both the website and the in-ISO offline docs remains `data/tools.json` in this repository. After catalog edits:

```bash
node scripts/sync-catalogs.js --build   # updates builder/docs (offline) + docs/data/tools.js mirror
```

Pushing `data/tools.json` to `main` dispatches a rebuild of the website (see `.github/workflows/notify-website.yml`).

In-tree guides kept here for GitHub browsing:

- [VM Appliance Guide](./VM_APPLIANCE_GUIDE.md)
