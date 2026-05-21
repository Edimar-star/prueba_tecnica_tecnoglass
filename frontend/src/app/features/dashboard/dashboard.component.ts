import { Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { DashboardService } from '../../core/services/dashboard.service';
import type { DashboardData } from '../../core/models';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [RouterLink],
  templateUrl: './dashboard.component.html',
})
export class DashboardComponent implements OnInit {
  private svc = inject(DashboardService);

  data    = signal<DashboardData | null>(null);
  loading = signal(true);
  error   = signal('');

  get activas()    { return this.data()?.ordenes.filter(o => o.Estado === 'ACTIVA') ?? []; }
  get completadas(){ return this.data()?.ordenes.filter(o => o.Estado === 'COMPLETADA') ?? []; }
  get totalVentanas() {
    return this.data()?.ordenes.reduce((s, o) => s + o.TotalVentanas, 0) ?? 0;
  }
  get ventanasCompletadas() {
    return this.data()?.ordenes.reduce((s, o) => s + o.VentanasCompletadas, 0) ?? 0;
  }

  ngOnInit() {
    this.svc.resumen().subscribe({
      next:  d  => { this.data.set(d); this.loading.set(false); },
      error: () => { this.error.set('Error al cargar el dashboard'); this.loading.set(false); },
    });
  }

  badgeClass(estado: string): string {
    return estado === 'ACTIVA' ? 'bg-success' : 'bg-secondary';
  }

  stationColor(orden: number): string {
    return ['', '#3b82f6', '#8b5cf6', '#f59e0b', '#10b981'][orden] ?? '#94a3b8';
  }
}
