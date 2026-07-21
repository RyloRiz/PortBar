//
//  ServiceCatalog.swift
//  PortBar
//

import Foundation

enum ServiceCatalog {
    static let version = 7

    private static let starterPackServiceLabels: Set<String> = [
        "Node server", "Vite", "Next.js", "SvelteKit", "Nuxt", "Angular", "Storybook"
    ]

    private static let catalogFilters = [
        QuickFilter(symbol: "terminal.fill", label: "Node server", ports: "3000-3020", processPattern: "node", tint: "#3C873A"),
        QuickFilter(symbol: "bolt.fill", label: "Vite", ports: "4173, 5173-5175", processPattern: "vite", launchCommandPattern: "vite", tint: "#8B5CF6"),
        QuickFilter(symbol: "shippingbox.fill", label: "Docker", ports: "2375, 2376", processPattern: "docker", tint: "#2496ED"),
        QuickFilter(symbol: "cylinder.fill", label: "Postgres", ports: "5432", processPattern: "postgres, postmaster", tint: "#6366F1"),
        QuickFilter(symbol: "square.stack.3d.up.fill", label: "Redis", ports: "6379", processPattern: "redis", tint: "#DC382D"),
        QuickFilter(symbol: "leaf.fill", label: "Django", ports: "8000-8005", processPattern: "python", launchCommandPattern: "manage.py, django", tint: "#0C8C55"),
        QuickFilter(symbol: "point.3.connected.trianglepath.dotted", label: "GraphQL", ports: "4000, 4001", processPattern: "graphql", launchCommandPattern: "graphql, apollo", tint: "#E10098"),
        QuickFilter(symbol: "cylinder.split.1x2", label: "MySQL", ports: "3306", processPattern: "mysqld, mysql", tint: "#F29111"),
        QuickFilter(symbol: "arrow.right.square.fill", label: "Next.js", ports: "3000-3020", processPattern: "next", launchCommandPattern: "next, next-server", tint: "#6B7280"),
        QuickFilter(symbol: "s.circle.fill", label: "SvelteKit", ports: "4173, 5173-5175", processPattern: "svelte", launchCommandPattern: "svelte-kit", tint: "#FF3E00"),
        QuickFilter(symbol: "n.circle.fill", label: "Nuxt", ports: "3000, 3001", processPattern: "nuxt", launchCommandPattern: "nuxt, nuxi", tint: "#00C58E"),
        QuickFilter(symbol: "a.circle.fill", label: "Angular", ports: "4200-4220", processPattern: "ng, angular", launchCommandPattern: "ng, angular", tint: "#DD0031"),
        QuickFilter(symbol: "book.closed.fill", label: "Storybook", ports: "6006, 6007, 7007", processPattern: "storybook", launchCommandPattern: "storybook", tint: "#FF4785"),
        QuickFilter(symbol: "sparkles", label: "Astro", ports: "3000, 4321", processPattern: "node", launchCommandPattern: "astro", tint: "#FF5D01"),
        QuickFilter(symbol: "arrow.triangle.turn.up.right.diamond.fill", label: "Remix", ports: "3000-3020", processPattern: "node", launchCommandPattern: "remix", tint: "#121212"),
        QuickFilter(symbol: "g.circle.fill", label: "Gatsby", ports: "8000, 9000", processPattern: "node", launchCommandPattern: "gatsby", tint: "#663399"),
        QuickFilter(symbol: "v.circle.fill", label: "Vue CLI", ports: "8080", processPattern: "node", launchCommandPattern: "vue-cli-service", tint: "#42B883"),
        QuickFilter(symbol: "circle.hexagongrid.fill", label: "SolidStart", ports: "3000-3020", processPattern: "node", launchCommandPattern: "vinxi, solid-start", tint: "#2C4F7C"),
        QuickFilter(symbol: "q.circle.fill", label: "Qwik City", ports: "4173, 5173-5175", processPattern: "node", launchCommandPattern: "qwik", tint: "#18B6F6"),
        QuickFilter(symbol: "iphone", label: "React Native", ports: "8081", processPattern: "metro", launchCommandPattern: "metro", tint: "#61DAFB"),
        QuickFilter(symbol: "figure.run", label: "Expo", ports: "8081, 19000-19002", processPattern: "node", launchCommandPattern: "expo", tint: "#4630EB"),
        QuickFilter(symbol: "bird.fill", label: "Flutter DevTools", ports: "9100", processPattern: "dart", launchCommandPattern: "devtools", tint: "#54C5F8"),
        QuickFilter(symbol: "bolt.car.fill", label: "Capacitor", ports: "8100", processPattern: "node", launchCommandPattern: "capacitor", tint: "#119EFF"),
        QuickFilter(symbol: "flame.fill", label: "Flask", ports: "5000, 5001, 8000", processPattern: "flask", launchCommandPattern: "flask", tint: "#111827"),
        QuickFilter(symbol: "bolt.heart.fill", label: "FastAPI", ports: "8000, 8001", processPattern: "uvicorn, fastapi", launchCommandPattern: "uvicorn", tint: "#009688"),
        QuickFilter(symbol: "l.circle.fill", label: "Laravel", ports: "8000, 8001", processPattern: "php, artisan", launchCommandPattern: "artisan", tint: "#FF2D20"),
        QuickFilter(symbol: "tram.fill", label: "Rails", ports: "3000, 3001", processPattern: "rails, puma", launchCommandPattern: "rails, puma", tint: "#CC0000"),
        QuickFilter(symbol: "cup.and.saucer.fill", label: "Spring Boot", ports: "8080, 8081", processPattern: "java, spring", tint: "#6DB33F"),
        QuickFilter(symbol: "number.circle.fill", label: ".NET", ports: "5000, 5001", processPattern: "dotnet", launchCommandPattern: "dotnet", tint: "#512BD4"),
        QuickFilter(symbol: "bolt.horizontal.circle.fill", label: "Phoenix", ports: "4000", processPattern: "beam, phoenix", launchCommandPattern: "phx.server, phoenix", tint: "#FD4F00"),
        QuickFilter(symbol: "e.circle.fill", label: "Express", ports: "3000, 8080", processPattern: "node", launchCommandPattern: "express", tint: "#000000"),
        QuickFilter(symbol: "n.circle.fill", label: "NestJS", ports: "3000-3020", processPattern: "node", launchCommandPattern: "nest", tint: "#E0234E"),
        QuickFilter(symbol: "h.circle.fill", label: "Hono", ports: "3000-3020", processPattern: "node, bun", launchCommandPattern: "hono", tint: "#FF5B4D"),
        QuickFilter(symbol: "a.circle.fill", label: "AdonisJS", ports: "3333", processPattern: "node", launchCommandPattern: "adonis", tint: "#5A45FF"),
        QuickFilter(symbol: "k.circle.fill", label: "Ktor", ports: "8080", processPattern: "java", launchCommandPattern: "ktor", tint: "#FF318C"),
        QuickFilter(symbol: "swift", label: "Vapor", ports: "8080", processPattern: "vapor", launchCommandPattern: "vapor", tint: "#F05138"),
        QuickFilter(symbol: "g.circle.fill", label: "Gin", ports: "8080", processPattern: "go", launchCommandPattern: "gin", tint: "#00ADD8"),
        QuickFilter(symbol: "leaf.circle.fill", label: "MongoDB", ports: "27017", processPattern: "mongod", tint: "#47A248"),
        QuickFilter(symbol: "cylinder.split.1x2.fill", label: "MariaDB", ports: "3306", processPattern: "mariadbd, mariadb", tint: "#003545"),
        QuickFilter(symbol: "magnifyingglass.circle.fill", label: "Elasticsearch", ports: "9200, 9300", processPattern: "elasticsearch", tint: "#FEC514"),
        QuickFilter(symbol: "hare.fill", label: "RabbitMQ", ports: "5672, 15672", processPattern: "rabbitmq, beam", tint: "#FF6600"),
        QuickFilter(symbol: "waveform.path.ecg", label: "Kafka", ports: "9092-9094", processPattern: "kafka", launchCommandPattern: "kafka", tint: "#231F20"),
        QuickFilter(symbol: "point.3.connected.trianglepath.dotted", label: "Zookeeper", ports: "2181", processPattern: "zookeeper", tint: "#4B9CD3"),
        QuickFilter(symbol: "dot.radiowaves.left.and.right", label: "NATS", ports: "4222, 8222", processPattern: "nats", tint: "#27AAE1"),
        QuickFilter(symbol: "memorychip.fill", label: "Memcached", ports: "11211", processPattern: "memcached", tint: "#9C27B0"),
        QuickFilter(symbol: "shippingbox.circle.fill", label: "MinIO", ports: "9000, 9001", processPattern: "minio", tint: "#C72C48"),
        QuickFilter(symbol: "s.square.fill", label: "Supabase", ports: "8000, 54321-54324, 54327, 54328", processPattern: "supabase", tint: "#3ECF8E"),
        QuickFilter(symbol: "leaf.circle.fill", label: "CouchDB", ports: "5984", processPattern: "beam, couchdb", tint: "#E42528"),
        QuickFilter(symbol: "tablecells.fill", label: "ClickHouse", ports: "8123, 9000", processPattern: "clickhouse", tint: "#FFCC01"),
        QuickFilter(symbol: "bolt.circle.fill", label: "Neo4j", ports: "7474, 7687", processPattern: "neo4j", tint: "#4581C3"),
        QuickFilter(symbol: "arrow.triangle.2.circlepath.circle.fill", label: "InfluxDB", ports: "8086", processPattern: "influxd", tint: "#22ADF6"),
        QuickFilter(symbol: "cube.fill", label: "Meilisearch", ports: "7700", processPattern: "meilisearch", tint: "#FF5CAA"),
        QuickFilter(symbol: "magnifyingglass", label: "Typesense", ports: "8108", processPattern: "typesense", tint: "#2F6FED"),
        QuickFilter(symbol: "wave.3.right.circle.fill", label: "Pulsar", ports: "6650, 8080", processPattern: "pulsar", tint: "#188FFF"),
        QuickFilter(symbol: "arrow.triangle.branch", label: "Traefik", ports: "80, 443, 8080", processPattern: "traefik", tint: "#24A1C1"),
        QuickFilter(symbol: "c.circle.fill", label: "Caddy", ports: "80, 443, 2019", processPattern: "caddy", tint: "#1F88C0"),
        QuickFilter(symbol: "network", label: "NGINX", ports: "80, 443", processPattern: "nginx", tint: "#009639"),
        QuickFilter(symbol: "key.fill", label: "Keycloak", ports: "8080, 8443", processPattern: "keycloak", tint: "#4D4A86"),
        QuickFilter(symbol: "server.rack", label: "Consul", ports: "8500, 8600", processPattern: "consul", tint: "#CA2171"),
        QuickFilter(symbol: "lock.shield.fill", label: "Vault", ports: "8200", processPattern: "vault", tint: "#FFD814"),
        QuickFilter(symbol: "shippingbox.and.arrow.backward.fill", label: "LocalStack", ports: "4510-4559, 4566", processPattern: "localstack", tint: "#E86F15"),
        QuickFilter(symbol: "cube.transparent", label: "Dapr", ports: "3500, 50001", processPattern: "daprd", tint: "#0D2192"),
        QuickFilter(symbol: "arrow.left.arrow.right.circle.fill", label: "Envoy", ports: "9901, 10000", processPattern: "envoy", tint: "#AC6198"),
        QuickFilter(symbol: "rectangle.3.group.bubble.fill", label: "Firebase emulators", ports: "4000, 4400, 4500, 5001, 5002, 8080, 8085, 9099, 9199, 9299", processPattern: "node", launchCommandPattern: "firebase", tint: "#FFA000"),
        QuickFilter(symbol: "cloud.fill", label: "Appwrite", ports: "80, 443", processPattern: "appwrite", tint: "#F02E65"),
        QuickFilter(symbol: "p.circle.fill", label: "PocketBase", ports: "8090", processPattern: "pocketbase", tint: "#B8DBE4"),
        QuickFilter(symbol: "s.square.fill", label: "Strapi", ports: "1337", processPattern: "node", launchCommandPattern: "strapi", tint: "#4945FF"),
        QuickFilter(symbol: "d.circle.fill", label: "Directus", ports: "8055", processPattern: "node", launchCommandPattern: "directus", tint: "#6644FF"),
        QuickFilter(symbol: "p.circle.fill", label: "Payload", ports: "3000-3020", processPattern: "node", launchCommandPattern: "payload", tint: "#1E1E1E"),
        QuickFilter(symbol: "arrow.triangle.branch", label: "Hasura", ports: "8080", processPattern: "graphql-engine, hasura", launchCommandPattern: "hasura", tint: "#1EB4D4"),
        QuickFilter(symbol: "chart.xyaxis.line", label: "Prometheus", ports: "9090, 9093", processPattern: "prometheus", launchCommandPattern: "prometheus, alertmanager", tint: "#E6522C"),
        QuickFilter(symbol: "chart.bar.xaxis", label: "Grafana", ports: "3000-3020", processPattern: "grafana", launchCommandPattern: "grafana", tint: "#F46800"),
        QuickFilter(symbol: "point.3.filled.connected.trianglepath.dotted", label: "Jaeger", ports: "16686, 4317, 4318", processPattern: "jaeger", tint: "#60D0E4"),
        QuickFilter(symbol: "waveform.path", label: "OpenTelemetry", ports: "4317, 4318, 55679", processPattern: "otelcol", tint: "#4F62E8"),
        QuickFilter(symbol: "envelope.fill", label: "Mailpit", ports: "1025, 8025", processPattern: "mailpit", tint: "#15A968"),
        QuickFilter(symbol: "envelope.badge.fill", label: "MailHog", ports: "1025, 8025", processPattern: "mailhog", tint: "#E17B24"),
        QuickFilter(symbol: "s.circle.fill", label: "Sentry", ports: "9000", processPattern: "sentry", tint: "#362D59"),
        QuickFilter(symbol: "cylinder.split.1x2.fill", label: "Temporal", ports: "7233, 8233", processPattern: "temporal", tint: "#0B4C5F"),
        QuickFilter(symbol: "globe", label: "BrowserSync", ports: "3000, 3001", processPattern: "node", launchCommandPattern: "browser-sync", tint: "#F69E2F"),
        QuickFilter(symbol: "curlybraces.square.fill", label: "JSON Server", ports: "3000", processPattern: "node", launchCommandPattern: "json-server", tint: "#8B5A2B"),
        QuickFilter(symbol: "network", label: "ngrok", ports: "4040", processPattern: "ngrok", tint: "#1F1E37"),
        QuickFilter(symbol: "play.rectangle.fill", label: "Playwright report", ports: "9323", processPattern: "node", launchCommandPattern: "playwright", tint: "#45BA4B")
    ]

    /// The complete catalog remains available in Settings, but a new install
    /// starts with a focused frontend-web selection instead of every service.
    static let filters: [QuickFilter] = catalogFilters.map { filter in
        var starterFilter = filter
        starterFilter.isEnabled = starterPackServiceLabels.contains(filter.label)
        return starterFilter
    }

    static let packs = [
        ServicePack(id: "frontend-web", label: "Frontend web", description: "Node, web frameworks, bundlers, and component labs", bestFor: "frontend engineers building browser-based products and design systems", symbol: "rectangle.3.group.fill", sectionID: "frontend", serviceLabels: ["Node server", "Vite", "Next.js", "SvelteKit", "Nuxt", "Angular", "Storybook", "Astro", "Remix", "Gatsby", "Vue CLI", "SolidStart", "Qwik City"]),
        ServicePack(id: "backend-web", label: "Backend APIs", description: "Application frameworks and API servers", bestFor: "API, platform, and full-stack engineers running local application servers", symbol: "server.rack", sectionID: "backend", serviceLabels: ["Node server", "Django", "GraphQL", "Flask", "FastAPI", "Laravel", "Rails", "Spring Boot", ".NET", "Phoenix", "Express", "NestJS", "Hono", "AdonisJS", "Ktor", "Vapor", "Gin"]),
        ServicePack(id: "platforms", label: "CMS & platforms", description: "Headless CMS, backend platforms, and GraphQL", bestFor: "product teams using self-hosted backends, CMSs, or BaaS tools", symbol: "square.3.layers.3d", sectionID: "platforms", serviceLabels: ["Appwrite", "PocketBase", "Strapi", "Directus", "Payload", "Hasura", "Supabase"]),
        ServicePack(id: "data", label: "Data & queues", description: "Databases, search, caches, and brokers", bestFor: "backend and data engineers running local dependencies", symbol: "cylinder.split.1x2.fill", sectionID: "data", serviceLabels: ["Postgres", "Redis", "MySQL", "MongoDB", "MariaDB", "Elasticsearch", "RabbitMQ", "Kafka", "Zookeeper", "NATS", "Memcached", "MinIO", "CouchDB", "ClickHouse", "Neo4j", "InfluxDB", "Meilisearch", "Typesense", "Pulsar"]),
        ServicePack(id: "infrastructure", label: "Infrastructure", description: "Containers, proxies, service mesh, and local cloud", bestFor: "platform, DevOps, and full-stack engineers recreating production locally", symbol: "shippingbox.fill", sectionID: "infrastructure", serviceLabels: ["Docker", "Traefik", "Caddy", "NGINX", "Keycloak", "Consul", "Vault", "LocalStack", "Dapr", "Envoy", "Firebase emulators"]),
        ServicePack(id: "observability", label: "Observability", description: "Metrics, tracing, mail, and local workflows", bestFor: "engineers validating telemetry, background workflows, and outbound email", symbol: "waveform.path.ecg", sectionID: "observability", serviceLabels: ["Prometheus", "Grafana", "Jaeger", "OpenTelemetry", "Mailpit", "MailHog", "Sentry", "Temporal"]),
        ServicePack(id: "mobile", label: "Mobile", description: "React Native, Expo, Flutter, and Capacitor", bestFor: "mobile engineers testing device and simulator builds", symbol: "iphone", sectionID: "mobile", serviceLabels: ["React Native", "Expo", "Flutter DevTools", "Capacitor"]),
        ServicePack(id: "utilities", label: "Dev utilities", description: "Proxies, mock APIs, and browser test reports", bestFor: "web engineers working with local fixtures, tunnels, and test artifacts", symbol: "wrench.and.screwdriver.fill", sectionID: "utilities", serviceLabels: ["BrowserSync", "JSON Server", "ngrok", "Playwright report"])
    ]

    static func serviceDescription(for label: String) -> String {
        switch label {
        case "Node server": return "General-purpose Node.js development server, usually beginning at port 3000."
        case "Vite", "Astro", "SolidStart", "Qwik City": return "Fast local web development server for this framework."
        case "Next.js", "Remix", "Gatsby", "Nuxt", "SvelteKit", "Angular", "Vue CLI": return "Local application server and development tooling for this web framework."
        case "Storybook": return "Component workshop for building and reviewing UI in isolation."
        case "React Native", "Expo", "Flutter DevTools", "Capacitor": return "Mobile development tooling for device, simulator, or web preview workflows."
        case "Django", "Flask", "FastAPI", "Laravel", "Rails", "Spring Boot", ".NET", "Phoenix", "Express", "NestJS", "Hono", "AdonisJS", "Ktor", "Vapor", "Gin": return "Local application or API server for this backend framework."
        case "GraphQL", "Hasura": return "GraphQL API server, gateway, or developer console."
        case "Postgres", "MySQL", "MariaDB", "MongoDB", "CouchDB", "ClickHouse", "Neo4j", "InfluxDB": return "Local database service used by applications and development tools."
        case "Redis", "Memcached": return "In-memory cache or lightweight local data store."
        case "Elasticsearch", "Meilisearch", "Typesense": return "Local search engine and indexing service."
        case "RabbitMQ", "Kafka", "Zookeeper", "NATS", "Pulsar", "Temporal": return "Messaging, eventing, or background-workflow service."
        case "MinIO": return "S3-compatible local object storage."
        case "Docker": return "Docker daemon API for local containers."
        case "Traefik", "Caddy", "NGINX", "Envoy": return "Local reverse proxy, ingress, or edge server."
        case "Keycloak", "Consul", "Vault", "Dapr": return "Local infrastructure service for identity, discovery, secrets, or service-to-service development."
        case "LocalStack", "Firebase emulators": return "Local cloud-service emulator for developing without remote infrastructure."
        case "Appwrite", "PocketBase", "Strapi", "Directus", "Payload", "Supabase": return "Self-hosted backend platform or content service for local product development."
        case "Prometheus", "Grafana", "Jaeger", "OpenTelemetry", "Sentry": return "Local metrics, tracing, telemetry, or error-monitoring service."
        case "Mailpit", "MailHog": return "Local email catcher for safely inspecting outbound messages."
        case "BrowserSync": return "Browser reload and synchronized device preview server."
        case "JSON Server": return "Quick local REST API backed by fixture data."
        case "ngrok": return "Tunnel inspector for exposing a local server to the internet."
        case "Playwright report": return "Local web server for viewing Playwright test reports."
        default: return "Local development service monitored on its standard listener ports."
        }
    }

    static let sections = [
        ServiceSection(id: "frontend", label: "Frontend web", serviceLabels: ["Vite", "Next.js", "SvelteKit", "Nuxt", "Angular", "Storybook", "Astro", "Remix", "Gatsby", "Vue CLI", "SolidStart", "Qwik City"]),
        ServiceSection(id: "backend", label: "Backend APIs", serviceLabels: ["Node server", "Django", "GraphQL", "Flask", "FastAPI", "Laravel", "Rails", "Spring Boot", ".NET", "Phoenix", "Express", "NestJS", "Hono", "AdonisJS", "Ktor", "Vapor", "Gin"]),
        ServiceSection(id: "platforms", label: "CMS & platforms", serviceLabels: ["Appwrite", "PocketBase", "Strapi", "Directus", "Payload", "Hasura", "Supabase"]),
        ServiceSection(id: "data", label: "Data & queues", serviceLabels: ["Postgres", "Redis", "MySQL", "MongoDB", "MariaDB", "Elasticsearch", "RabbitMQ", "Kafka", "Zookeeper", "NATS", "Memcached", "MinIO", "CouchDB", "ClickHouse", "Neo4j", "InfluxDB", "Meilisearch", "Typesense", "Pulsar"]),
        ServiceSection(id: "infrastructure", label: "Infrastructure & proxy", serviceLabels: ["Docker", "Traefik", "Caddy", "NGINX", "Keycloak", "Consul", "Vault", "LocalStack", "Dapr", "Envoy", "Firebase emulators"]),
        ServiceSection(id: "observability", label: "Observability & workflows", serviceLabels: ["Prometheus", "Grafana", "Jaeger", "OpenTelemetry", "Mailpit", "MailHog", "Sentry", "Temporal"]),
        ServiceSection(id: "mobile", label: "Mobile", serviceLabels: ["React Native", "Expo", "Flutter DevTools", "Capacitor"]),
        ServiceSection(id: "utilities", label: "Dev utilities", serviceLabels: ["BrowserSync", "JSON Server", "ngrok", "Playwright report"])
    ]

    static func repaired(
        _ savedFilters: [QuickFilter],
        includeMissingServices: Bool,
        refreshServiceAppearance: Bool
    ) -> [QuickFilter] {
        let repaired = savedFilters.map { filter -> QuickFilter in
            guard let template = template(for: filter.label) else { return filter }
            var updated = filter
            if filter.label.localizedCaseInsensitiveCompare("Node") == .orderedSame {
                updated.label = template.label
            }
            // Service identity is catalog-owned (it is not configurable in Settings),
            // so saved entries must always follow a corrected system symbol.
            updated.symbol = template.symbol
            if updated.ports.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.ports = template.ports
            }
            if updated.processPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.processPattern = template.processPattern
            }
            if updated.launchCommandPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.launchCommandPattern = template.launchCommandPattern
            }
            if refreshServiceAppearance {
                updated.tint = template.tint
            }
            return updated
        }

        guard includeMissingServices else { return repaired }
        let existingLabels = Set(repaired.map { normalizedLabel($0.label) })
        return repaired + filters.filter { !existingLabels.contains(normalizedLabel($0.label)) }
    }

    /// Returns the immutable catalog definition for a built-in service group.
    static func defaults(for label: String) -> QuickFilter? {
        template(for: label)
    }

    static func applyingStarterPack(to filters: [QuickFilter]) -> [QuickFilter] {
        filters.map { filter in
            var updated = filter
            updated.isEnabled = starterPackServiceLabels.contains(filter.label)
            return updated
        }
    }

    private static func template(for label: String) -> QuickFilter? {
        let normalized = normalizedLabel(label)
        return filters.first { normalizedLabel($0.label) == normalized }
    }

    private static func normalizedLabel(_ label: String) -> String {
        label.localizedCaseInsensitiveCompare("Node") == .orderedSame ? "node server" : label.lowercased()
    }
}
