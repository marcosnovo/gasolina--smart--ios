import Foundation

struct Loc {
    private let l: AppLanguage

    init(_ language: AppLanguage) {
        l = language.resolved
    }

    private func s(_ es: String, _ en: String, _ fr: String, _ de: String, _ pt: String) -> String {
        switch l {
        case .es: es
        case .en: en
        case .fr: fr
        case .de: de
        case .pt: pt
        case .system: en
        }
    }

    // MARK: - Tabs

    var tabMap: String { s("Mapa", "Map", "Carte", "Karte", "Mapa") }
    var tabFavorites: String { s("Favoritos", "Favourites", "Favoris", "Favoriten", "Favoritos") }
    var tabSearch: String { s("Buscar", "Search", "Rechercher", "Suchen", "Pesquisar") }
    var tabSettings: String { s("Ajustes", "Settings", "Réglages", "Einstellungen", "Definições") }

    // MARK: - Onboarding

    var onboardingTitle: String { s("Ahorra cada vez\nque repostas", "Save every time\nyou refuel", "Économisez à\nchaque plein", "Sparen Sie bei\njedem Tanken", "Poupe sempre\nque abastece") }
    var onboardingSubtitle: String { s("Encuentra la gasolinera más barata cerca de ti y decide cuándo repostar.", "Find the cheapest fuel station near you and decide when to refuel.", "Trouvez la station la moins chère et décidez quand faire le plein.", "Finden Sie die günstigste Tankstelle und entscheiden Sie, wann Sie tanken.", "Encontre o posto mais barato perto de si e decida quando abastecer.") }
    var onboardingStart: String { s("Empezar", "Get started", "Commencer", "Starten", "Começar") }
    var onboardingCountryTitle: String { s("Tu país", "Your country", "Votre pays", "Ihr Land", "O seu país") }
    var onboardingCountrySubtitle: String { s("Selecciona dónde buscas gasolineras.", "Select where you search for stations.", "Sélectionnez où vous cherchez des stations.", "Wählen Sie, wo Sie Tankstellen suchen.", "Selecione onde procura postos.") }
    var onboardingVehicleTitle: String { s("Tu vehículo", "Your vehicle", "Votre véhicule", "Ihr Fahrzeug", "O seu veículo") }
    var onboardingVehicleHint: String { s("Puedes añadir más en Ajustes.", "You can add more in Settings.", "Ajoutez-en d'autres dans Réglages.", "Weitere in den Einstellungen.", "Pode adicionar mais nas Definições.") }
    var onboardingContinue: String { s("Continuar", "Continue", "Continuer", "Weiter", "Continuar") }
    var onboardingDefaultVehicle: String { s("Mi coche", "My car", "Ma voiture", "Mein Auto", "O meu carro") }
    var onboardingLocationTitle: String { s("Tu ubicación", "Your location", "Votre position", "Ihr Standort", "A sua localização") }
    var onboardingLocationBody: String { s("Necesitamos tu ubicación para encontrar gasolineras cerca de ti.\n\nNo compartimos tu posición con nadie.", "We need your location to find fuel stations near you.\n\nWe never share your location.", "Nous avons besoin de votre position pour trouver des stations proches.\n\nNous ne partageons jamais votre position.", "Wir benötigen Ihren Standort, um Tankstellen in Ihrer Nähe zu finden.\n\nWir geben Ihren Standort nicht weiter.", "Precisamos da sua localização para encontrar postos perto de si.\n\nNunca partilhamos a sua localização.") }
    var onboardingAllowLocation: String { s("Permitir ubicación", "Allow location", "Autoriser la localisation", "Standort erlauben", "Permitir localização") }
    var onboardingNotNow: String { s("Ahora no", "Not now", "Pas maintenant", "Nicht jetzt", "Agora não") }
    var name: String { s("Nombre", "Name", "Nom", "Name", "Nome") }
    var namePlaceholder: String { s("Ej: Mi coche", "E.g.: My car", "Ex : Ma voiture", "Z.B.: Mein Auto", "Ex: O meu carro") }
    var fuel: String { s("Combustible", "Fuel", "Carburant", "Kraftstoff", "Combustível") }

    // MARK: - Map

    var mapLoading: String { s("Cargando mapa...", "Loading map...", "Chargement de la carte...", "Karte wird geladen...", "A carregar o mapa...") }
    var mapExpandRadius: String { s("Amplía el radio de búsqueda", "Expand search radius", "Élargissez le rayon de recherche", "Suchradius erweitern", "Aumente o raio de pesquisa") }
    var mapLoadingStations: String { s("Cargando estaciones...", "Loading stations...", "Chargement des stations...", "Stationen werden geladen...", "A carregar estações...") }
    var mapLoadError: String { s("Error al cargar", "Loading error", "Erreur de chargement", "Ladefehler", "Erro ao carregar") }
    var mapRetry: String { s("Reintentar", "Retry", "Réessayer", "Erneut versuchen", "Tentar novamente") }
    var mapNoLocation: String { s("Ubicación no disponible", "Location unavailable", "Position indisponible", "Standort nicht verfügbar", "Localização indisponível") }
    var mapEnableLocation: String { s("Activa la ubicación en Ajustes o busca por ciudad.", "Enable location in Settings or search by city.", "Activez la localisation dans Réglages ou recherchez par ville.", "Standort in Einstellungen aktivieren oder nach Stadt suchen.", "Ative a localização nas Definições ou pesquise por cidade.") }
    var mapEnableLocationAction: String { s("Activar ubicación", "Enable location", "Activer la localisation", "Standort aktivieren", "Ativar localização") }
    var mapOpenSettings: String { s("Abrir Ajustes", "Open Settings", "Ouvrir Réglages", "Einstellungen öffnen", "Abrir Definições") }
    var mapSearchByCity: String { s("Buscar por ciudad", "Search by city", "Rechercher par ville", "Nach Stadt suchen", "Pesquisar por cidade") }
    var mapQuickSearch: String { s("Ciudad", "City", "Ville", "Stadt", "Cidade") }
    var mapSearchRadius: String { s("Radio de búsqueda", "Search radius", "Rayon de recherche", "Suchradius", "Raio de pesquisa") }
    var mapApply: String { s("Aplicar", "Apply", "Appliquer", "Anwenden", "Aplicar") }
    var mapRadius: String { s("Radio", "Radius", "Rayon", "Radius", "Raio") }
    var navigate: String { s("Navegar", "Navigate", "Naviguer", "Navigieren", "Navegar") }
    var howToGet: String { s("Cómo llegar", "Get directions", "Itinéraire", "Wegbeschreibung", "Como chegar") }
    var close: String { s("Cerrar", "Close", "Fermer", "Schließen", "Fechar") }
    var stations: String { s("gasolineras", "stations", "stations", "Tankstellen", "postos") }
    var chargers: String { s("cargadores", "chargers", "bornes", "Ladestationen", "carregadores") }

    func mapNoStations(_ km: Int) -> String {
        s("Sin gasolineras en \(km) km", "No stations within \(km) km", "Aucune station dans \(km) km", "Keine Tankstellen im Umkreis von \(km) km", "Sem postos em \(km) km")
    }

    var listTitle: String { s("Gasolineras", "Stations", "Stations", "Tankstellen", "Postos") }
    var listRecommended: String { s("Recomendado", "Recommended", "Recommandé", "Empfohlen", "Recomendado") }
    var listPrice: String { s("Precio", "Price", "Prix", "Preis", "Preço") }
    var listDistance: String { s("Distancia", "Distance", "Distance", "Entfernung", "Distância") }
    func listResultsInRadius(_ count: Int, _ km: Int) -> String {
        s("\(count) en \(km) km", "\(count) within \(km) km", "\(count) dans \(km) km", "\(count) im Umkreis von \(km) km", "\(count) em \(km) km")
    }

    // MARK: - Search

    var searchingLocation: String { s("Buscando ubicación...", "Searching location...", "Recherche en cours...", "Standort wird gesucht...", "A pesquisar localização...") }
    var searchNoResults: String { s("Sin resultados", "No results", "Aucun résultat", "Keine Ergebnisse", "Sem resultados") }
    var searchTryOther: String { s("Prueba con otra dirección o ciudad", "Try another address or city", "Essayez une autre adresse ou ville", "Andere Adresse oder Stadt versuchen", "Tente outro endereço ou cidade") }
    var searchPlaceholder: String { s("Dirección, ciudad o código postal", "Address, city or postcode", "Adresse, ville ou code postal", "Adresse, Stadt oder Postleitzahl", "Morada, cidade ou código postal") }
    var searchTitle: String { s("Buscar", "Search", "Rechercher", "Suchen", "Pesquisar") }
    var searchPromptTitle: String { s("Busca gasolineras\ncerca de una dirección", "Find stations\nnear an address", "Trouvez des stations\nprès d'une adresse", "Tankstellen\nin der Nähe suchen", "Encontre postos\nperto de uma morada") }
    var searchPromptBody: String { s("Escribe una dirección, ciudad o código postal para encontrar las gasolineras más baratas de esa zona.", "Enter an address, city or postcode to find the cheapest stations in that area.", "Saisissez une adresse ou ville pour trouver les stations les moins chères.", "Adresse oder Postleitzahl eingeben, um günstige Tankstellen zu finden.", "Escreva uma morada ou cidade para encontrar os postos mais baratos.") }
    var searchSort: String { s("Ordenar", "Sort", "Trier", "Sortieren", "Ordenar") }
    var searchByPrice: String { s("Precio", "Price", "Prix", "Preis", "Preço") }
    var searchByDistance: String { s("Distancia", "Distance", "Distance", "Entfernung", "Distância") }

    func searchStationsNear(_ count: Int, _ name: String) -> String {
        s("\(count) gasolineras cerca de \(name)", "\(count) stations near \(name)", "\(count) stations près de \(name)", "\(count) Tankstellen nahe \(name)", "\(count) postos perto de \(name)")
    }

    func searchResults(_ count: Int) -> String {
        s("\(count) resultados", "\(count) results", "\(count) résultats", "\(count) Ergebnisse", "\(count) resultados")
    }

    // MARK: - Favorites

    var favAddresses: String { s("Direcciones", "Addresses", "Adresses", "Adressen", "Moradas") }
    var favStations: String { s("Gasolineras", "Stations", "Stations", "Tankstellen", "Postos") }
    var favAll: String { s("Todo", "All", "Tout", "Alle", "Tudo") }
    var favTitle: String { s("Favoritos", "Favourites", "Favoris", "Favoriten", "Favoritos") }
    var favEmpty: String { s("Aún no tienes\nfavoritos", "You don't have\nany favourites yet", "Vous n'avez pas\nencore de favoris", "Sie haben noch\nkeine Favoriten", "Ainda não tem\nfavoritos") }
    var favEmptyBody: String { s("Añade gasolineras desde el mapa o guarda direcciones desde el buscador.", "Add stations from the map or save addresses from the search.", "Ajoutez des stations depuis la carte ou sauvegardez des adresses.", "Tankstellen von der Karte oder Adressen aus der Suche hinzufügen.", "Adicione postos a partir do mapa ou guarde moradas da pesquisa.") }
    var favNoNearby: String { s("Sin gasolineras cercanas", "No nearby stations", "Aucune station à proximité", "Keine Tankstellen in der Nähe", "Sem postos próximos") }

    // MARK: - Settings

    var settingsTitle: String { s("Ajustes", "Settings", "Réglages", "Einstellungen", "Definições") }
    var settingsCountry: String { s("País", "Country", "Pays", "Land", "País") }
    var settingsCountryFooter: String { s("Selecciona el país donde quieres buscar gasolineras. Los tipos de combustible se ajustan automáticamente.", "Select the country where you want to search. Fuel types adjust automatically.", "Sélectionnez le pays. Les types de carburant s'ajustent automatiquement.", "Wählen Sie das Land. Kraftstoffarten passen sich automatisch an.", "Selecione o país. Os tipos de combustível ajustam-se automaticamente.") }
    var settingsLanguage: String { s("Idioma", "Language", "Langue", "Sprache", "Idioma") }
    var settingsLanguageFooter: String { s("El idioma de la aplicación. «Auto» usa el idioma del dispositivo.", "The app language. «Auto» uses the device language.", "La langue de l'app. « Auto » utilise la langue de l'appareil.", "Die App-Sprache. «Auto» verwendet die Gerätesprache.", "O idioma da app. «Auto» usa o idioma do dispositivo.") }
    var settingsVehicles: String { s("Mis vehículos", "My vehicles", "Mes véhicules", "Meine Fahrzeuge", "Os meus veículos") }
    var settingsAddVehicle: String { s("Añadir vehículo", "Add vehicle", "Ajouter un véhicule", "Fahrzeug hinzufügen", "Adicionar veículo") }
    var settingsVehicleFooter: String { s("El vehículo seleccionado determina el tipo de combustible en el mapa y los precios mostrados.", "The selected vehicle determines the fuel type on the map and displayed prices.", "Le véhicule sélectionné détermine le type de carburant et les prix affichés.", "Das ausgewählte Fahrzeug bestimmt Kraftstoff und angezeigte Preise.", "O veículo selecionado determina o combustível no mapa e os preços.") }
    var settingsMap: String { s("Mapa", "Map", "Carte", "Karte", "Mapa") }
    var settingsSearchRadius: String { s("Radio de búsqueda", "Search radius", "Rayon de recherche", "Suchradius", "Raio de pesquisa") }
    var settingsCharging: String { s("Puntos de carga eléctrica", "Electric charging points", "Bornes de recharge", "Ladestationen", "Pontos de carregamento") }
    var settingsChargingFooter: String { s("Muestra los puntos de carga eléctrica en el mapa junto a las gasolineras, diferenciados con un icono azul.", "Shows electric charging points on the map alongside fuel stations, marked with a blue icon.", "Affiche les bornes de recharge sur la carte, identifiées par une icône bleue.", "Zeigt Ladestationen auf der Karte mit blauem Symbol an.", "Mostra os pontos de carregamento no mapa com ícone azul.") }
    var settingsNavigation: String { s("Navegación", "Navigation", "Navigation", "Navigation", "Navegação") }
    var settingsNavSingle: String { s("Se usará directamente al pulsar Navegar.", "Will be used directly when you tap Navigate.", "Utilisé directement en appuyant sur Naviguer.", "Wird direkt beim Tippen auf Navigieren verwendet.", "Será usado diretamente ao tocar em Navegar.") }
    var settingsNavMultiple: String { s("Al pulsar Navegar podrás elegir entre los servicios seleccionados.", "Tap Navigate to choose between the selected services.", "Choisissez parmi les services sélectionnés.", "Beim Navigieren zwischen den Diensten wählen.", "Ao navegar poderá escolher entre os serviços.") }
    var settingsAppearance: String { s("Apariencia", "Appearance", "Apparence", "Darstellung", "Aparência") }
    var settingsTheme: String { s("Tema", "Theme", "Thème", "Design", "Tema") }
    var settingsNotifications: String { s("Notificaciones", "Notifications", "Notifications", "Benachrichtigungen", "Notificações") }
    var settingsNotifDisabled: String { s("Desactivadas", "Disabled", "Désactivées", "Deaktiviert", "Desativadas") }
    var settingsNotifOpenSystem: String { s("Actívalas en Ajustes del sistema.", "Enable them in system Settings.", "Activez-les dans Réglages du système.", "In den Systemeinstellungen aktivieren.", "Ative nas Definições do sistema.") }
    var settingsOpen: String { s("Abrir", "Open", "Ouvrir", "Öffnen", "Abrir") }
    var settingsNotifEnable: String { s("Activar notificaciones", "Enable notifications", "Activer les notifications", "Benachrichtigungen aktivieren", "Ativar notificações") }
    var settingsNotifFooter: String { s("Recibe alertas cuando los precios cambien según tus preferencias.", "Receive alerts when prices change according to your preferences.", "Recevez des alertes quand les prix changent.", "Benachrichtigungen bei Preisänderungen erhalten.", "Receba alertas quando os preços mudem.") }
    var settingsInfo: String { s("Información", "Information", "Informations", "Informationen", "Informação") }
    var settingsDataSource: String { s("Fuente de datos", "Data source", "Source de données", "Datenquelle", "Fonte de dados") }
    var settingsUpdate: String { s("Actualización", "Update frequency", "Mise à jour", "Aktualisierung", "Atualização") }
    var settingsChargingSource: String { s("Carga eléctrica", "Electric charging", "Recharge électrique", "Elektro-Laden", "Carregamento") }
    var settingsPrivacy: String { s("Tu ubicación se usa solo en el dispositivo. No se comparte ni almacena.", "Your location is only used on-device. It is never shared or stored.", "Votre position est uniquement utilisée sur l'appareil.", "Ihr Standort wird nur auf dem Gerät verwendet.", "A sua localização é usada apenas no dispositivo.") }
    var settingsAutomatic: String { s("Automático", "Automatic", "Automatique", "Automatisch", "Automático") }
    var settingsAutoCountryFooter: String { s("Detecta el país automáticamente según tu ubicación.", "Automatically detects the country based on your location.", "Détecte le pays automatiquement selon votre position.", "Erkennt das Land automatisch anhand Ihres Standorts.", "Deteta o país automaticamente pela sua localização.") }
    func settingsActiveAlerts(_ count: Int) -> String {
        s("\(count) activas", "\(count) active", "\(count) actives", "\(count) aktiv", "\(count) ativas")
    }
    var settingsNoAlerts: String { s("Ninguna activa", "None active", "Aucune active", "Keine aktiv", "Nenhuma ativa") }
    var settingsOfficialData: String { s("Datos oficiales", "Official data", "Données officielles", "Offizielle Daten", "Dados oficiais") }
    var settingsChargingOn: String { s("Carga eléctrica", "EV charging", "Recharge élec.", "E-Ladestationen", "Carregamento") }

    // MARK: - Vehicle Edit

    var vehicleEdit: String { s("Editar vehículo", "Edit vehicle", "Modifier le véhicule", "Fahrzeug bearbeiten", "Editar veículo") }
    var vehicleNew: String { s("Nuevo vehículo", "New vehicle", "Nouveau véhicule", "Neues Fahrzeug", "Novo veículo") }
    var cancel: String { s("Cancelar", "Cancel", "Annuler", "Abbrechen", "Cancelar") }
    var save: String { s("Guardar", "Save", "Enregistrer", "Speichern", "Guardar") }
    var edit: String { s("Editar", "Edit", "Modifier", "Bearbeiten", "Editar") }
    var delete: String { s("Eliminar", "Delete", "Supprimer", "Löschen", "Eliminar") }
    var brand: String { s("Marca", "Brand", "Marque", "Marke", "Marca") }
    var brandPlaceholder: String { s("Ej: Toyota, Seat...", "E.g.: Toyota, Ford...", "Ex : Toyota, Renault...", "Z.B.: Toyota, VW...", "Ex: Toyota, Seat...") }
    var vehicleType: String { s("Tipo de vehículo", "Vehicle type", "Type de véhicule", "Fahrzeugtyp", "Tipo de veículo") }
    var color: String { s("Color", "Colour", "Couleur", "Farbe", "Cor") }
    var tank: String { s("Depósito", "Tank", "Réservoir", "Tank", "Depósito") }
    var tankSize: String { s("Tamaño", "Size", "Taille", "Größe", "Tamanho") }
    var liters: String { s("Litros", "Litres", "Litres", "Liter", "Litros") }
    var consumption: String { s("Consumo", "Consumption", "Consommation", "Verbrauch", "Consumo") }
    var avgConsumption: String { s("Consumo medio", "Average consumption", "Consommation moyenne", "Durchschnittsverbrauch", "Consumo médio") }
    var consumptionFooter: String { s("Se usa para calcular el coste real por kilómetro.", "Used to calculate actual cost per kilometre.", "Utilisé pour calculer le coût réel par km.", "Zur Berechnung der Kosten pro km.", "Usado para calcular o custo real por km.") }

    // MARK: - Station Detail

    var detailTrend: String { s("TENDENCIA ZONA", "AREA TREND", "TENDANCE ZONE", "TREND GEBIET", "TENDÊNCIA ZONA") }
    var detailZoneAvg: String { s("Media zona", "Area average", "Moyenne zone", "Durchschnitt", "Média zona") }
    var detailCost100km: String { s("Coste 100 km", "Cost per 100 km", "Coût 100 km", "Kosten 100 km", "Custo 100 km") }
    var detailFillTank: String { s("Llenar depósito", "Fill tank", "Faire le plein", "Volltanken", "Encher depósito") }
    var detailDistance: String { s("Distancia", "Distance", "Distance", "Entfernung", "Distância") }
    var detailPrices: String { s("PRECIOS", "PRICES", "PRIX", "PREISE", "PREÇOS") }

    func detailDays(_ count: Int) -> String {
        s("\(count) días", "\(count) days", "\(count) jours", "\(count) Tage", "\(count) dias")
    }

    func detailTrendCaption(_ radiusKm: Double) -> String {
        let radiusText = "\(Int(radiusKm.rounded())) km"
        return s(
            "Basada en tu zona actual y el radio de \(radiusText).",
            "Based on your current area and the \(radiusText) radius.",
            "Basée sur votre zone actuelle et le rayon de \(radiusText).",
            "Basierend auf Ihrem aktuellen Gebiet und dem Radius von \(radiusText).",
            "Baseada na sua zona atual e no raio de \(radiusText)."
        )
    }

    func detailSaving(_ amount: String) -> String {
        s("Ahorras \(amount) vs media", "You save \(amount) vs average", "Vous économisez \(amount)", "Sie sparen \(amount)", "Poupa \(amount) vs média")
    }

    func detailDeltaPerLiter(_ amount: String) -> String {
        s("\(amount) por litro vs media", "\(amount) per litre vs average", "\(amount) par litre vs moyenne", "\(amount) pro Liter vs Durchschnitt", "\(amount) por litro vs média")
    }

    func detailStationCount(_ count: Int) -> String {
        s("\(count) estaciones comparadas", "\(count) stations compared", "\(count) stations comparées", "\(count) verglichene Stationen", "\(count) postos comparados")
    }

    // MARK: - Charging Detail

    var chargingConnectors: String { s("CONECTORES", "CONNECTORS", "CONNECTEURS", "STECKER", "CONECTORES") }
    var chargingPoints: String { s("Puntos de carga", "Charging points", "Points de charge", "Ladepunkte", "Pontos de carregamento") }
    var chargingMaxPower: String { s("Potencia máxima", "Max power", "Puissance max", "Max. Leistung", "Potência máxima") }
    var chargingCost: String { s("Coste", "Cost", "Coût", "Kosten", "Custo") }
    var chargingMunicipality: String { s("Municipio", "Municipality", "Commune", "Gemeinde", "Município") }

    func chargingPointCount(_ count: Int) -> String {
        s("\(count) puntos", "\(count) points", "\(count) points", "\(count) Punkte", "\(count) pontos")
    }

    // MARK: - Appearance

    func appearanceName(_ a: AppAppearance) -> String {
        switch a {
        case .system: s("Sistema", "System", "Système", "System", "Sistema")
        case .light: s("Claro", "Light", "Clair", "Hell", "Claro")
        case .dark: s("Oscuro", "Dark", "Sombre", "Dunkel", "Escuro")
        }
    }

    // MARK: - Vehicle Types

    func vehicleTypeName(_ t: VehicleType) -> String {
        switch t {
        case .sedan: s("Sedán", "Saloon", "Berline", "Limousine", "Sedã")
        case .suv: s("SUV", "SUV", "SUV", "SUV", "SUV")
        case .hatchback: s("Compacto", "Compact", "Compacte", "Kompakt", "Compacto")
        case .van: s("Furgoneta", "Van", "Fourgon", "Transporter", "Carrinha")
        case .motorcycle: s("Moto", "Motorbike", "Moto", "Motorrad", "Mota")
        }
    }

    // MARK: - Vehicle Colors

    func vehicleColorName(_ c: VehicleColor) -> String {
        switch c {
        case .black: s("Negro", "Black", "Noir", "Schwarz", "Preto")
        case .white: s("Blanco", "White", "Blanc", "Weiß", "Branco")
        case .silver: s("Plata", "Silver", "Argent", "Silber", "Prata")
        case .red: s("Rojo", "Red", "Rouge", "Rot", "Vermelho")
        case .blue: s("Azul", "Blue", "Bleu", "Blau", "Azul")
        case .darkBlue: s("Azul oscuro", "Dark blue", "Bleu foncé", "Dunkelblau", "Azul escuro")
        case .green: s("Verde", "Green", "Vert", "Grün", "Verde")
        case .orange: s("Naranja", "Orange", "Orange", "Orange", "Laranja")
        case .yellow: s("Amarillo", "Yellow", "Jaune", "Gelb", "Amarelo")
        case .brown: s("Marrón", "Brown", "Marron", "Braun", "Castanho")
        }
    }

    // MARK: - Alert Types

    func alertTypeName(_ a: AlertType) -> String {
        switch a {
        case .priceDropped: s("Bajada de precio", "Price drop", "Baisse de prix", "Preissenkung", "Descida de preço")
        case .belowNearbyAverage: s("Por debajo de la media", "Below average", "En dessous de la moyenne", "Unter Durchschnitt", "Abaixo da média")
        case .cheapestNearby: s("Más barata cercana", "Cheapest nearby", "Moins chère à proximité", "Günstigste in der Nähe", "Mais barato próximo")
        case .stationBecameExpensive: s("Subida de precio", "Price rise", "Hausse de prix", "Preisanstieg", "Subida de preço")
        case .belowUserTargetPrice: s("Precio objetivo", "Target price reached", "Prix cible atteint", "Zielpreis erreicht", "Preço alvo atingido")
        }
    }

    // MARK: - Data Freshness

    func freshnessText(_ f: DataFreshness) -> String {
        switch f {
        case .realtime: s("Tiempo real", "Real-time", "Temps réel", "Echtzeit", "Tempo real")
        case .within30min: "≤30 min"
        case .within1hour: s("~1 hora", "~1 hour", "~1 heure", "~1 Stunde", "~1 hora")
        case .daily: s("Diaria", "Daily", "Quotidienne", "Täglich", "Diária")
        }
    }

    // MARK: - Price Opportunity

    func opportunityLabel(_ opp: PriceOpportunity) -> String {
        switch opp {
        case .great: s("Buena oportunidad", "Great opportunity", "Bonne affaire", "Gute Gelegenheit", "Boa oportunidade")
        case .fair: s("Precio normal", "Normal price", "Prix normal", "Normaler Preis", "Preço normal")
        case .poor: s("Por encima de la media", "Above average", "Au-dessus de la moyenne", "Über Durchschnitt", "Acima da média")
        case .unknown: s("Sin datos suficientes", "Insufficient data", "Données insuffisantes", "Nicht genügend Daten", "Dados insuficientes")
        }
    }

    // MARK: - Worth It Level

    func worthMessage(_ w: WorthItLevel) -> String {
        switch w {
        case .neutral: s("Precio similar a la media", "Similar to average", "Prix similaire à la moyenne", "Ähnlich wie Durchschnitt", "Semelhante à média")
        case .moderate: s("Puede compensar", "May be worth it", "Peut valoir le coup", "Könnte sich lohnen", "Pode compensar")
        case .good: s("Buena oportunidad", "Good opportunity", "Bonne opportunité", "Gute Gelegenheit", "Boa oportunidade")
        }
    }

    func worthShort(_ w: WorthItLevel) -> String {
        switch w {
        case .neutral: s("Similar", "Similar", "Similaire", "Ähnlich", "Similar")
        case .moderate: s("Compensa", "Worth it", "Intéressant", "Lohnt sich", "Compensa")
        case .good: s("Buen precio", "Good price", "Bon prix", "Guter Preis", "Bom preço")
        }
    }

    // MARK: - Fuel Decision Verdicts

    func verdictTitle(_ v: FuelDecision.Verdict) -> String {
        switch v {
        case .refuelNow: s("Reposta ahora", "Refuel now", "Faites le plein", "Jetzt tanken", "Abasteça agora")
        case .goodOption: s("Buena oportunidad", "Good option", "Bonne option", "Gute Option", "Boa opção")
        case .average: s("Precio normal", "Normal price", "Prix normal", "Normaler Preis", "Preço normal")
        case .tooFar: s("No compensa desviarse", "Not worth the detour", "Détour non rentable", "Umweg lohnt nicht", "Desvio não compensa")
        case .noData: s("Sin datos suficientes", "Insufficient data", "Données insuffisantes", "Nicht genügend Daten", "Dados insuficientes")
        }
    }

    // MARK: - Data Freshness (StationStore)

    var dataNoData: String { s("Sin datos", "No data", "Pas de données", "Keine Daten", "Sem dados") }
    var dataUpdatedNow: String { s("Actualizado ahora", "Updated now", "Mis à jour", "Gerade aktualisiert", "Atualizado agora") }
    var dataUpdating: String { s("Actualizando... · ", "Updating... · ", "Mise à jour... · ", "Aktualisierung... · ", "Aktualisieren... · ") }

    func dataMinutesAgo(_ min: Int) -> String {
        s("Hace \(min) min", "\(min) min ago", "Il y a \(min) min", "Vor \(min) Min.", "Há \(min) min")
    }

    func dataHoursAgo(_ hours: Int) -> String {
        s("Hace \(hours) h", "\(hours) h ago", "Il y a \(hours) h", "Vor \(hours) Std.", "Há \(hours) h")
    }

    // MARK: - Charging Speed

    func chargingSpeedLabel(_ speed: ChargingStation.SpeedCategory) -> String {
        switch speed {
        case .fast: s("Carga rápida", "Fast charging", "Charge rapide", "Schnellladung", "Carga rápida")
        case .semiFast: s("Semi-rápida", "Semi-fast", "Semi-rapide", "Halbschnell", "Semi-rápida")
        case .slow: s("Carga lenta", "Slow charging", "Charge lente", "Langsames Laden", "Carga lenta")
        case .unknown: s("Desconocida", "Unknown", "Inconnue", "Unbekannt", "Desconhecida")
        }
    }
}
