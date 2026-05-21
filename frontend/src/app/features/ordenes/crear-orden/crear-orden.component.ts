import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { OrdenesService } from '../../../core/services/ordenes.service';

@Component({
  selector: 'app-crear-orden',
  standalone: true,
  imports: [ReactiveFormsModule, RouterLink],
  templateUrl: './crear-orden.component.html',
})
export class CrearOrdenComponent {
  private fb     = inject(FormBuilder);
  private svc    = inject(OrdenesService);
  private router = inject(Router);

  form = this.fb.group({
    codigo:          ['', [Validators.required, Validators.minLength(3)]],
    total_ventanas:  [1,  [Validators.required, Validators.min(1), Validators.max(1000)]],
  });

  loading = signal(false);
  error   = signal('');

  submit() {
    if (this.form.invalid) return;
    this.loading.set(true);
    this.error.set('');

    const { codigo, total_ventanas } = this.form.value;
    this.svc.crear(codigo!, total_ventanas!).subscribe({
      next:  orden => this.router.navigate(['/ordenes', orden.Id]),
      error: err   => {
        this.error.set(err.error?.detail ?? 'Error al crear la orden');
        this.loading.set(false);
      },
    });
  }
}
