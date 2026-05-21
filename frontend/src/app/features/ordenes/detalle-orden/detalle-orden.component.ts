import { Component, OnInit, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { SlicePipe } from '@angular/common';
import { OrdenesService } from '../../../core/services/ordenes.service';
import { VentanasService } from '../../../core/services/ventanas.service';
import type { OrdenDetalle, Ventana } from '../../../core/models';

const STATION_NAMES: Record<number, string> = { 1: 'corte', 2: 'troquel', 3: 'ensamble', 4: 'empaque' };

@Component({
  selector: 'app-detalle-orden',
  standalone: true,
  imports: [RouterLink, SlicePipe],
  templateUrl: './detalle-orden.component.html',
})
export class DetalleOrdenComponent implements OnInit {
  private route       = inject(ActivatedRoute);
  private router      = inject(Router);
  private ordenesSvc  = inject(OrdenesService);
  private ventanasSvc = inject(VentanasService);

  orden    = signal<OrdenDetalle | null>(null);
  loading  = signal(true);
  error    = signal('');
  advancing = signal<string | null>(null);

  // edición de código
  editando       = signal(false);
  nuevoCodigoEdit = signal('');

  // eliminación de orden
  confirmandoEliminar = signal(false);

  // agregar ventanas
  cantidadAgregar = signal(1);

  // busy flag para mutaciones (editar, eliminar orden, agregar ventanas)
  saving = signal(false);

  // eliminación individual de ventana
  removingVentana = signal<string | null>(null);

  ngOnInit() { this.cargar(); }

  cargar() {
    const id = Number(this.route.snapshot.paramMap.get('id'));
    this.loading.set(true);
    this.ordenesSvc.detalle(id).subscribe({
      next:  d  => { this.orden.set(d); this.loading.set(false); },
      error: () => { this.error.set('Error al cargar la orden'); this.loading.set(false); },
    });
  }

  avanzar(v: Ventana) {
    this.advancing.set(v.Id);
    this.ventanasSvc.avanzar(v.Id).subscribe({
      next:  () => { this.advancing.set(null); this.cargar(); },
      error: err => {
        this.error.set(err.error?.detail ?? 'Error al avanzar la ventana');
        this.advancing.set(null);
      },
    });
  }

  iniciarEdicion() {
    this.nuevoCodigoEdit.set(this.orden()!.Codigo);
    this.editando.set(true);
    this.error.set('');
  }

  guardarEdicion() {
    const codigo = this.nuevoCodigoEdit().trim();
    if (!codigo) return;
    this.saving.set(true);
    this.ordenesSvc.editar(this.orden()!.Id, codigo).subscribe({
      next: updated => {
        this.orden.update(o => o ? { ...o, Codigo: updated.Codigo } : o);
        this.editando.set(false);
        this.saving.set(false);
      },
      error: err => {
        this.error.set(err.error?.detail ?? 'Error al editar la orden');
        this.saving.set(false);
      },
    });
  }

  eliminarOrden() {
    this.saving.set(true);
    this.ordenesSvc.eliminar(this.orden()!.Id).subscribe({
      next:  () => this.router.navigate(['/ordenes']),
      error: err => {
        this.error.set(err.error?.detail ?? 'Error al eliminar la orden');
        this.confirmandoEliminar.set(false);
        this.saving.set(false);
      },
    });
  }

  agregarVentanas() {
    const cantidad = this.cantidadAgregar();
    if (cantidad < 1) return;
    this.saving.set(true);
    this.error.set('');
    this.ordenesSvc.agregarVentanas(this.orden()!.Id, cantidad).subscribe({
      next:  () => { this.saving.set(false); this.cargar(); },
      error: err => {
        this.error.set(err.error?.detail ?? 'Error al agregar ventanas');
        this.saving.set(false);
      },
    });
  }

  eliminarVentana(v: Ventana) {
    this.removingVentana.set(v.Id);
    this.error.set('');
    this.ordenesSvc.eliminarVentana(this.orden()!.Id, v.Id).subscribe({
      next:  () => { this.removingVentana.set(null); this.cargar(); },
      error: err => {
        this.error.set(err.error?.detail ?? 'Error al eliminar la ventana');
        this.removingVentana.set(null);
      },
    });
  }

  stationBadge(v: Ventana): string {
    if (v.Estado === 'PENDIENTE') return 'pendiente';
    if (v.Estado === 'COMPLETADA') return 'empaque';
    return STATION_NAMES[v.OrdenEstacion ?? 0] ?? '';
  }

  stationLabel(v: Ventana): string {
    if (v.Estado === 'PENDIENTE') return 'Pendiente';
    return v.EstacionActual ?? '—';
  }

  canAdvance(v: Ventana): boolean {
    return v.Estado !== 'COMPLETADA';
  }

  badgeOrden(estado: string): string {
    return estado === 'ACTIVA' ? 'bg-success' : 'bg-secondary';
  }
}
