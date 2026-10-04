// Push notifications through Firebase Cloud Messaging (HTTP v1). Ready once GOOGLE_SERVICE_ACCOUNT_JSON holds a
// service account of the Firebase project (FIREBASE_PROJECT_ID overrides the project in that file). Without it the
// notifications still reach the app's list; only the phone alert is skipped.
import type { User } from './accounts.ts';
import { db } from './data/db.ts';
import { googleAccessToken, serviceAccount } from './google.ts';

export const pushReady = () => !!serviceAccount() && !!(process.env.FIREBASE_PROJECT_ID || serviceAccount()?.project_id);

export async function sendPush(u: User, title: string, body: string, data: Record<string, string>) {
  if (!pushReady()) return;
  const project = process.env.FIREBASE_PROJECT_ID || serviceAccount()!.project_id!;
  try {
    const token = await googleAccessToken('https://www.googleapis.com/auth/firebase.messaging');
    for (const device of [...u.pushTokens]) {
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${project}/messages:send`, {
        method: 'POST',
        headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
        body: JSON.stringify({
          message: {
            token: device,
            notification: { title, body: body.slice(0, 180) },
            data,
            android: { priority: 'high', notification: { channel_id: 'samrah', sound: 'default' } },
            apns: { payload: { aps: { sound: 'default' } } },
          },
        }),
      });
      // the app was removed or the token replaced: forget it
      if (res.status === 404 || res.status === 400) {
        const text = await res.text();
        if (/UNREGISTERED|INVALID_ARGUMENT/.test(text)) {
          u.pushTokens = u.pushTokens.filter((t) => t !== device);
          db.touch();
        }
      }
    }
  } catch (e) {
    console.error('[push]', (e as Error).message);
  }
}
