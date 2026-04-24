# Lyon Pocket — Site web

Site vitrine single-page pour l'app Lyon Pocket.

## Contenu

- `index.html` — Landing page marketing (toutes les fonctionnalités + carrousel)
- `support.html` — Page d'assistance (FAQ + contact)
- `privacy.html` — Politique de confidentialité
- `style.css` — Styles (design glassmorphism, animations, responsive)
- `script.js` — Carrousel + reveal on scroll
- `assets/` — Illustrations et icône de l'app

## Aperçu local

```bash
cd website
python3 -m http.server 8000
# puis ouvrir http://localhost:8000
```

## URLs à renseigner dans App Store Connect

Une fois déployé (GitHub Pages, Netlify, Cloudflare Pages, Vercel…), remplacez `https://votre-domaine.com` ci-dessous :

| Champ App Store Connect | Valeur |
| --- | --- |
| **URL marketing** | `https://votre-domaine.com/` |
| **URL d'assistance** | `https://votre-domaine.com/support.html` |
| **URL de politique de confidentialité** | `https://votre-domaine.com/privacy.html` |
| **Copyright** | `2026 Solal Gendrin` |

## Déploiement rapide (Cloudflare Pages)

```bash
# Depuis la racine du repo
cd website
npx wrangler pages deploy . --project-name lyon-pocket
```

Ou GitHub Pages : pousser le dossier `website/` sur une branche `gh-pages` et activer Pages dans les settings du repo.

## Aucune dépendance

Vanilla HTML/CSS/JS. Une seule police Google Fonts (Inter). Tout le reste est local.
