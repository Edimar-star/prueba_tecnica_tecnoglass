import { Routes } from '@angular/router';
import { authGuard } from './core/auth/auth.guard';

export const routes: Routes = [
  { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
  {
    path: 'login',
    loadComponent: () => import('./features/login/login.component').then(m => m.LoginComponent),
  },
  {
    path: 'dashboard',
    canActivate: [authGuard],
    loadComponent: () => import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent),
  },
  {
    path: 'ordenes',
    canActivate: [authGuard],
    loadComponent: () => import('./features/ordenes/ordenes-list.component').then(m => m.OrdenesListComponent),
  },
  {
    path: 'ordenes/crear',
    canActivate: [authGuard],
    loadComponent: () => import('./features/ordenes/crear-orden/crear-orden.component').then(m => m.CrearOrdenComponent),
  },
  {
    path: 'ordenes/:id',
    canActivate: [authGuard],
    loadComponent: () => import('./features/ordenes/detalle-orden/detalle-orden.component').then(m => m.DetalleOrdenComponent),
  },
  {
    path: 'trazabilidad',
    canActivate: [authGuard],
    loadComponent: () => import('./features/trazabilidad/trazabilidad.component').then(m => m.TrazabilidadComponent),
  },
  {
    path: 'trazabilidad/:id',
    canActivate: [authGuard],
    loadComponent: () => import('./features/trazabilidad/trazabilidad.component').then(m => m.TrazabilidadComponent),
  },
  { path: '**', redirectTo: 'dashboard' },
];
