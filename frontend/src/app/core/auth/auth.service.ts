import { HttpClient } from '@angular/common/http';
import { Injectable, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import { switchMap } from 'rxjs';
import { environment } from '../../../environments/environment';
import type { TokenResponse, Usuario } from '../models';
import { StorageEncryptionService } from './storage-encryption.service';

const TOKEN_KEY = 'tg_token';
const USER_KEY  = 'tg_user';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private http       = inject(HttpClient);
  private router     = inject(Router);
  private encryption = inject(StorageEncryptionService);

  currentUser = signal<Usuario | null>(null);
  private _cachedToken: string | null = null;

  /** Called by APP_INITIALIZER — decrypts localStorage and populates in-memory state
   *  before any route guard runs. */
  initSession(): Promise<void> {
    return this._restoreFromStorage();
  }

  login(username: string, password: string) {
    return this.http
      .post<TokenResponse>(`${environment.apiUrl}/auth/login`, { username, password })
      .pipe(
        switchMap(res => this._persistSession(res).then(() => res)),
      );
  }

  logout() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    this._cachedToken = null;
    this.currentUser.set(null);
    this.router.navigate(['/login']);
  }

  getToken(): string | null {
    return this._cachedToken;
  }

  // Decodes the JWT payload client-side to check exp without a backend round-trip.
  // Signature verification happens on every backend request.
  isAuthenticated(): boolean {
    const token = this._cachedToken;
    if (!token) return false;
    try {
      const base64  = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      const payload = JSON.parse(atob(base64));
      return typeof payload.exp === 'number' && payload.exp > Math.floor(Date.now() / 1000);
    } catch {
      return false;
    }
  }

  private async _restoreFromStorage(): Promise<void> {
    const encToken = localStorage.getItem(TOKEN_KEY);
    const encUser  = localStorage.getItem(USER_KEY);
    const [token, userJson] = await Promise.all([
      encToken ? this.encryption.decrypt(encToken) : Promise.resolve(null),
      encUser  ? this.encryption.decrypt(encUser)  : Promise.resolve(null),
    ]);
    this._cachedToken = token;
    try { if (userJson) this.currentUser.set(JSON.parse(userJson)); } catch { /* noop */ }
  }

  private async _persistSession(res: TokenResponse): Promise<void> {
    const [encToken, encUser] = await Promise.all([
      this.encryption.encrypt(res.access_token),
      this.encryption.encrypt(JSON.stringify(res.usuario)),
    ]);
    localStorage.setItem(TOKEN_KEY, encToken);
    localStorage.setItem(USER_KEY, encUser);
    this._cachedToken = res.access_token;
    this.currentUser.set(res.usuario);
  }
}
