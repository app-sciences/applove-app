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
