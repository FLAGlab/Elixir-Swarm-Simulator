# 🐝 Elixir Swarm Simulator

Un simulador web interactivo de comportamiento de enjambres (swarm behavior) construido con **Elixir** y el framework **Phoenix**. Este proyecto permite visualizar y experimentar con algoritmos de inteligencia de enjambre en tiempo real.

## 📋 Descripción del Proyecto

El Elixir Swarm Simulator es una aplicación web moderna que permite simular el comportamiento colectivo de agentes autónomos (como enjambres de abejas, bandadas de aves o cardúmenes de peces). Los usuarios pueden:

- **Crear simulaciones personalizadas** con diferentes parámetros
- **Visualizar en tiempo real** el movimiento y comportamiento de los agentes
- **Experimentar con algoritmos** de inteligencia artificial y comportamiento emergente
- **Analizar resultados** mediante estadísticas y métricas en tiempo real

## 🚀 Tecnologías Utilizadas

- **Elixir 1.15+**: Lenguaje funcional con soporte nativo para concurrencia
- **Phoenix 1.8.1**: Framework web moderno y escalable
- **Phoenix LiveView**: Interactividad en tiempo real sin necesidad de JavaScript complejo
- **Ecto + SQLite3**: Persistencia de datos
- **Tailwind CSS 4**: Diseño responsive y moderno
- **Heroicons**: Librería de iconos
- **Req**: Cliente HTTP para integraciones

## 📦 Requisitos Previos

Antes de empezar, asegúrate de tener instalado:

- **Elixir 1.15 o superior**
- **Erlang/OTP 26+** (incluido con Elixir)
- **Node.js 18+** (para compilar assets)
- **SQLite3** (incluido en la mayoría de sistemas)
- **Git**

Para verificar tu instalación:

```bash
elixir --version
erl -version
node --version
```

## 🛠️ Instalación y Configuración

### 1. Clonar el Repositorio

```bash
git clone <repository-url>
cd Elixir-Swarm-Simulator
```

### 2. Instalar Dependencias

Ejecuta el comando de setup que configura automáticamente el proyecto:

```bash
mix setup
```

Este comando realiza:
- Descarga e instala todas las dependencias con `mix deps.get`
- Configura la base de datos con `mix ecto.setup`
- Compila los assets (CSS, JS) con `mix assets.build`

### 3. Iniciar el Servidor

```bash
mix phx.server
```

O si prefieres usar IEx (Elixir interactive shell):

```bash
iex -S mix phx.server
```

## 🌐 Accediendo a la Aplicación

Una vez iniciado el servidor, abre tu navegador y visita:

```
http://localhost:4000
```

La aplicación está lista para usar. No requiere autenticación inicial.

## 📚 Estructura del Proyecto

```
├── lib/
│   ├── simulator/              # Lógica de negocio (Elixir puro)
│   │   └── agents/             # Módulos de simulación de agentes
│   └── simulator_web/          # Componentes web
│       ├── live/               # Phoenix LiveViews (UI interactiva)
│       ├── components/         # Componentes reutilizables
│       └── router.ex           # Rutas HTTP
├── priv/
│   └── repo/                   # Migraciones de base de datos
├── assets/
│   ├── css/                    # Estilos Tailwind CSS
│   └── js/                     # JavaScript/TypeScript
├── test/                       # Suite de pruebas
├── config/                     # Configuración del proyecto
└── mix.exs                     # Dependencias y configuración
```

## 🎮 Características Principales

### Simulaciones en Tiempo Real
- Visualización interactiva de agentes en movimiento
- Múltiples algoritmos de comportamiento disponibles
- Ajuste de parámetros en vivo sin reiniciar

### Persistencia de Datos
- Base de datos SQLite3 integrada
- Guardar y cargar configuraciones de simulaciones
- Historial de experimentos

### Interfaz Moderna
- Diseño responsive con Tailwind CSS
- Componentes interactivos con Phoenix LiveView
- Experiencia de usuario fluida y sin recargas

### Escalabilidad
- Arquitectura basada en procesos de Erlang/OTP
- Soporte para múltiples simulaciones concurrentes
- Optimizado para alto rendimiento

## 🧪 Pruebas

Ejecutar todas las pruebas:

```bash
mix test
```

Ejecutar pruebas de un archivo específico:

```bash
mix test test/simulator_web/live/some_live_test.exs
```

Ejecutar solo las pruebas fallidas:

```bash
mix test --failed
```

## 🔧 Comandos Útiles

| Comando | Descripción |
|---------|-------------|
| `mix setup` | Instalación inicial y configuración |
| `mix phx.server` | Inicia el servidor de desarrollo |
| `mix test` | Ejecuta la suite de pruebas |
| `mix format` | Formatea el código automáticamente |
| `mix precommit` | Ejecuta linters y pruebas (uso antes de commit) |
| `mix ecto.setup` | Configura la base de datos |
| `mix ecto.reset` | Reinicia la base de datos |
| `mix phx.gen.live` | Genera un nuevo LiveView (scaffolding) |

## 📝 Configuración

La configuración se encuentra en `config/`:

- **config.exs**: Configuración global
- **dev.exs**: Configuración de desarrollo
- **prod.exs**: Configuración de producción
- **test.exs**: Configuración de pruebas
- **runtime.exs**: Configuración en tiempo de ejecución

## 🌍 Despliegue en Producción

Para más información sobre opciones de despliegue:

- [Guías de Despliegue Phoenix](https://hexdocs.pm/phoenix/deployment.html)
- [Despliegue con Fly.io](https://hexdocs.pm/phoenix/fly.html)
- [Despliegue con Heroku](https://hexdocs.pm/phoenix_heroku/installation.html)

## 📖 Recursos y Documentación

### Documentación Oficial
- [Phoenix Documentation](https://hexdocs.pm/phoenix/overview.html)
- [Phoenix LiveView Guide](https://hexdocs.pm/phoenix_live_view/welcome.html)
- [Elixir Documentation](https://elixir-lang.org/docs.html)
- [Ecto Documentation](https://hexdocs.pm/ecto/Ecto.html)

### Comunidad
- [Elixir Forum](https://elixirforum.com/c/phoenix-forum)
- [Elixir Community](https://elixir-lang.org/community)
- [Discord Elixir/Erlang](https://discord.gg/elixir)

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📋 Pautas del Proyecto

Ver [AGENTS.md](AGENTS.md) para pautas de desarrollo, convenciones de código y estándares de arquitectura.

## 📄 Licencia

Este proyecto está bajo licencia. Consulta el archivo [LICENSE](LICENSE) para más detalles.

## 👤 Autor

Proyecto desarrollado como parte de investigación en inteligencia de enjambre y simulación multiagente.

---

**¿Problemas o Preguntas?**

Si encuentras algún issue o tienes preguntas, por favor abre una issue en el repositorio.
