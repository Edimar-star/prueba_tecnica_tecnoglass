import { Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { SlicePipe } from '@angular/common';
import { OrdenesService } from '../../core/services/ordenes.service';
import type { OrdenResumen } from '../../core/models';

@Component({
  selector: 'app-ordenes-list',
  standalone: true,
  imports: [RouterLink, SlicePipe],
  templateUrl: './ordenes-list.component.html',
})
export class OrdenesListComponent implements OnInit {
  private svc = inject(OrdenesService);

  ordenes  = signal<OrdenResumen[]>([]);
  loading  = signal(true);
  filtro   = signal<string | undefined>(undefined);

  ngOnInit() { this.cargar(); }

  cargar(estado?: string) {
    this.loading.set(true);
    this.filtro.set(estado);
    this.svc.listar(estado).subscribe({
      next:  data => { this.ordenes.set(data); this.loading.set(false); },
      error: ()   => this.loading.set(false),
    });
  }

  badgeClass(estado: string) {
    return estado === 'ACTIVA' ? 'bg-success' : 'bg-secondary';
  }
}
