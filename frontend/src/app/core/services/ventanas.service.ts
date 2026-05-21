import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { environment } from '../../../environments/environment';
import type { TrazabilidadVentana, Ventana } from '../models';

@Injectable({ providedIn: 'root' })
export class VentanasService {
  private http = inject(HttpClient);
  private base = `${environment.apiUrl}/ventanas`;

  avanzar(ventanaId: string, observacion?: string) {
    return this.http.post<Ventana>(`${this.base}/${ventanaId}/avanzar`, { observacion });
  }

  trazabilidad(ventanaId: string) {
    return this.http.get<TrazabilidadVentana>(`${this.base}/${ventanaId}/trazabilidad`);
  }

  porQR(codigoQR: string) {
    return this.http.get<TrazabilidadVentana>(`${this.base}/qr/${codigoQR}`);
  }

  qrImagen(ventanaId: string) {
    return this.http.get<{ ventana_id: string; qr_base64: string }>(`${this.base}/${ventanaId}/qr-imagen`);
  }
}
