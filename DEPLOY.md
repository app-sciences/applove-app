# Deploying applov to Firebase App Hosting

The web app lives in `apps/web` (Next.js). Pushes to `main` deploy it to the
Firebase project `appstake-5a80f` through `.github/workflows/deploy.yml`.
The workflow can also be run by hand from the Actions tab.

## How deploys work

Firebase App Hosting watches `main` in the GitHub repo. Every merge builds and
rolls out the app in `apps/web` to the Firebase project `appstake-5a80f`, with
no GitHub Actions deploy step. `.github/workflows/ci.yml` only typechecks and
builds pull requests so a broken change is caught before it reaches `main`.

## One-time setup

In the Firebase console (project `appstake-5a80f` → App Hosting) create a
backend with ID `applov`, root directory `apps/web`, live branch `main`, and
automatic rollouts on. If you choose a different backend ID, update `backendId`
in `firebase.json` (only used when deploying from the CLI).

## Runtime settings

CPU, memory and instance limits are in `apps/web/apphosting.yaml`.

## Data the app writes (Firestore)

Two server-side API routes write to Firestore in `appstake-5a80f`:

| Route | Collection | What it stores |
| --- | --- | --- |
| `POST /api/notify` | `waitlist` | Email addresses from the "Investing opens soon" dialog (one document per address). |
| `POST /api/submissions` | `submissions` | Developer app submissions, saved with `status: "pending"` for review. |

Setup:

1. Make sure Firestore is enabled in the project (it was used by the earlier
   appstake app, so it probably is).
2. On App Hosting the app uses its default service account, which can write
   through the Admin SDK. Locally, run
   `gcloud auth application-default login` (or set
   `GOOGLE_APPLICATION_CREDENTIALS`) to try the routes.
3. Only the server writes these collections. Check the project's Firestore
   rules so browsers cannot read or write `waitlist` and `submissions`
   directly.

Nothing reviews submissions yet. Read them in the Firebase console.
