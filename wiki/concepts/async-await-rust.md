---
tipo: concepto
tags: [programacion, rust, concurrencia]
fecha: 2026-06-12
fuente: "Inbox — prueba-rust-async.md"
---

# Async/await en Rust

## Modelo fundamental

Async/await en Rust se basa en **futures perezosos** (lazy futures) — las operaciones asíncronas no se ejecutan hasta que algo las espera explícitamente. Esto contrasta con los lenguajes donde los futures son eager (comienzan inmediatamente).

El runtime (típicamente [[tokio]]) es responsable de ejecutar estos futures y cambiar entre tareas cuando encuentran puntos de bloqueo.

## Zero-cost abstractions

Una característica distintiva de Rust es que async/await compila a código tan eficiente como si hubieras escrito la máquina de estados manualmente. No hay garbage collection de continuaciones ni overhead de cambio de contexto de threads.

## Implicaciones

- Las operaciones I/O pueden multiplexarse en un único thread con el runtime correcto.
- El compilador genera código máquina, no bytecode interpretado.
- Errores de borrow checker se detectan en compile-time incluso en código asíncronico.
