# Deploying applov to Firebase App Hosting

The web app lives in `apps/web` (Next.js). Pushes to `main` deploy it to the
Firebase project `appstake-5a80f` through `.github/workflows/deploy.yml`.
The workflow can also be run by hand from the Actions tab.

## One-time setup

1. **Create the App Hosting backend** in the Firebase console
   (project `appstake-5a80f` → App Hosting). Use backend ID `applov` and root
   directory `apps/web`. If you pick a different ID, update `backendId` in
   `firebase.json`.
2. **Create a deploy service account** in Google Cloud (project
   `appstake-5a80f`) and grant it **Firebase App Hosting Admin** and
   **Service Account User**. If a deploy fails with a missing permission,
   grant the role it names.
3. **Add the key to GitHub.** Create a JSON key for that service account and
   save its contents as the repository secret `FIREBASE_SERVICE_ACCOUNT`
   (Settings → Secrets and variables → Actions).
4. If the console connected the backend to this GitHub repo, turn off
   automatic rollouts so the workflow is the only thing that deploys.

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
