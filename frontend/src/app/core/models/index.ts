export interface Usuario {
  id: number;
  username: string;
  nombre: string;
  rol: 'ADMIN' | 'OPERADOR';
}

export interface TokenResponse {
  access_token: string;
  token_type: string;
  usuario: Usuario;
}

export interface Estacion {
  EstacionId: number;
  NombreEstacion: string;
  Orden: number;
}

export interface OrdenResumen {
  Id: number;
  Codigo: string;
  TotalVentanas: number;
  Estado: 'ACTIVA' | 'COMPLETADA';
  FechaCreacion: string;
  FechaCompletada: string | null;
  UsuarioCreador: string;
  VentanasCompletadas: number;
  VentanasEnProceso: number;
  VentanasPendientes: number;
  PorcentajeAvance: number;
}

export interface Ventana {
  Id: string;
  CodigoQR: string;
  Estado: 'PENDIENTE' | 'EN_PROCESO' | 'COMPLETADA';
  FechaCreacion: string;
  EstacionActualId: number | null;
  EstacionActual: string | null;
  OrdenEstacion: number | null;
}

export interface MovimientoVentana {
  Id: number;
  FechaMovimiento: string;
  Observacion: string | null;
  EstacionId: number;
  NombreEstacion: string;
  OrdenEstacion: number;
  UsuarioId: number;
  NombreUsuario: string;
}

export interface TrazabilidadVentana extends Ventana {
  OrdenProduccionId: number;
  CodigoOrden: string;
  movimientos: MovimientoVentana[];
}

export interface OrdenDetalle extends OrdenResumen {
  ventanas: Ventana[];
}

export interface DashboardData {
  ordenes: OrdenResumen[];
  distribucion_estaciones: (Estacion & { CantidadVentanas: number })[];
}
