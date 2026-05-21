import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { environment } from '../../../environments/environment';
import type { OrdenDetalle, OrdenResumen } from '../models';

@Injectable({ providedIn: 'root' })
export class OrdenesService {
  private http = inject(HttpClient);
  private base = `${environment.apiUrl}/ordenes`;

  listar(estado?: string) {
    let params = new HttpParams();
    if (estado) params = params.set('estado', estado);
    return this.http.get<OrdenResumen[]>(this.base, { params });
  }

  crear(codigo: string, total_ventanas: number) {
    return this.http.post<OrdenResumen>(this.base, { codigo, total_ventanas });
  }

  detalle(id: number) {
    return this.http.get<OrdenDetalle>(`${this.base}/${id}`);
  }

  editar(id: number, codigo: string) {
    return this.http.put<OrdenResumen>(`${this.base}/${id}`, { codigo });
  }

  eliminar(id: number) {
    return this.http.delete(`${this.base}/${id}`);
  }

  agregarVentanas(id: number, cantidad: number) {
    return this.http.post<{ ventanas_agregadas: number }>(`${this.base}/${id}/ventanas`, { cantidad });
  }

  eliminarVentana(ordenId: number, ventanaId: string) {
    return this.http.delete(`${this.base}/${ordenId}/ventanas/${ventanaId}`);
  }
}
