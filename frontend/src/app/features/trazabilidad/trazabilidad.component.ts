import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { SlicePipe } from '@angular/common';
import { VentanasService } from '../../core/services/ventanas.service';
import type { TrazabilidadVentana } from '../../core/models';

@Component({
  selector: 'app-trazabilidad',
  standalone: true,
  imports: [FormsModule, RouterLink, SlicePipe],
  templateUrl: './trazabilidad.component.html',
})
export class TrazabilidadComponent implements OnInit {
  private route = inject(ActivatedRoute);
  private svc   = inject(VentanasService);

  busqueda  = signal('');
  ventana   = signal<TrazabilidadVentana | null>(null);
  qrBase64  = signal<string | null>(null);
  loading   = signal(false);
  error     = signal('');

  ngOnInit() {
    const id = this.route.snapshot.paramMap.get('id');
    if (id) {
      this.busqueda.set(id);
      this.buscar();
    }
  }

  buscar() {
    const q = this.busqueda().trim();
    if (!q) return;
    this.loading.set(true);
    this.error.set('');
    this.ventana.set(null);
    this.qrBase64.set(null);

    const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(q);
    const obs = isUUID ? this.svc.trazabilidad(q) : this.svc.porQR(q);

    obs.subscribe({
      next: data => {
        this.ventana.set(data);
        this.loading.set(false);
        this.cargarQR(data.Id);
      },
      error: err => {
        this.error.set(err.error?.detail ?? 'Ventana no encontrada');
        this.loading.set(false);
      },
    });
  }

  private cargarQR(id: string) {
    this.svc.qrImagen(id).subscribe({
      next: res => this.qrBase64.set(res.qr_base64),
    });
  }

  stationOrder(orden: number): string {
    return ['', 'Corte', 'Troquel', 'Ensamble', 'Empaque'][orden] ?? '—';
  }

  estadoBadge(estado: string): string {
    const map: Record<string, string> = {
      PENDIENTE: 'bg-secondary',
      EN_PROCESO: 'bg-warning text-dark',
      COMPLETADA: 'bg-success',
    };
    return map[estado] ?? 'bg-secondary';
  }
}
