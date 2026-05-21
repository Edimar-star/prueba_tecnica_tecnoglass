import { Injectable } from '@angular/core';

// AES-256-GCM via Web Crypto API (browser-native, no external deps).
// The passphrase lives in the bundle so it provides encryption-at-rest against
// casual inspection of DevTools/localStorage, not against a determined attacker
// who has access to the JS bundle.  The real defence against XSS is CSP.
const PASSPHRASE = 'TGx9$k#mP2@nR7vL!qZ_AES256_Tecnoglass2024';
const SALT       = 'TG_salt_v1_2024';

@Injectable({ providedIn: 'root' })
export class StorageEncryptionService {
  private readonly keyPromise: Promise<CryptoKey>;

  constructor() {
    this.keyPromise = this._deriveKey();
  }

  async encrypt(plaintext: string): Promise<string> {
    const key = await this.keyPromise;
    const iv  = crypto.getRandomValues(new Uint8Array(12));
    const enc = await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv },
      key,
      new TextEncoder().encode(plaintext),
    );
    const buf = new Uint8Array(12 + enc.byteLength);
    buf.set(iv, 0);
    buf.set(new Uint8Array(enc), 12);
    return btoa(Array.from(buf, b => String.fromCharCode(b)).join(''));
  }

  async decrypt(ciphertext: string): Promise<string | null> {
    try {
      const key = await this.keyPromise;
      const buf = Uint8Array.from(atob(ciphertext), c => c.charCodeAt(0));
      const iv  = buf.slice(0, 12);
      const enc = buf.slice(12);
      const dec = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, enc);
      return new TextDecoder().decode(dec);
    } catch {
      return null;
    }
  }

  private async _deriveKey(): Promise<CryptoKey> {
    const rawPass = new TextEncoder().encode(PASSPHRASE);
    const rawSalt = new TextEncoder().encode(SALT);
    const keyMat  = await crypto.subtle.importKey(
      'raw', rawPass, { name: 'PBKDF2' }, false, ['deriveKey'],
    );
    return crypto.subtle.deriveKey(
      { name: 'PBKDF2', salt: rawSalt, iterations: 100_000, hash: 'SHA-256' },
      keyMat,
      { name: 'AES-GCM', length: 256 },
      false,
      ['encrypt', 'decrypt'],
    );
  }
}
