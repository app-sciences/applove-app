import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

// On Firebase App Hosting the default service account is picked up automatically.
// Locally, set GOOGLE_APPLICATION_CREDENTIALS (or run `gcloud auth application-default login`).
export function db() {
  const app = getApps()[0] ?? initializeApp({ projectId: process.env.GCLOUD_PROJECT || "appstake-5a80f" });
  return getFirestore(app);
}
