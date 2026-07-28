import 'package:flutter/material.dart';

/// Traducción de los nombres de icono que guarda la base de datos a [IconData].
///
/// Las tablas `habitos.icono`, `finanzas_metas.icono` y
/// `finanzas_categorias.icono` almacenan el nombre del icono de Material como
/// texto (`'savings'`, `'restaurant'`…), porque en web bastaba con
/// `<i class="material-icons">savings</i>`. En Flutter hay que resolverlo a un
/// [IconData] concreto: el tree-shaking de iconos impide construirlos por
/// codepoint en tiempo de ejecución.
abstract final class MaterialIconMap {
  static const IconData fallback = Icons.label_rounded;

  static const Map<String, IconData> _map = {
    // Genéricos
    'sell': Icons.sell_rounded,
    'label': Icons.label_rounded,
    'category': Icons.category_rounded,
    'check_circle': Icons.check_circle_rounded,
    'done': Icons.done_rounded,
    'star': Icons.star_rounded,
    'favorite': Icons.favorite_rounded,
    'bolt': Icons.bolt_rounded,
    'info': Icons.info_rounded,
    'warning': Icons.warning_rounded,
    'error': Icons.error_rounded,

    // Compras y comida
    'shopping_cart': Icons.shopping_cart_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'restaurant': Icons.restaurant_rounded,
    'fastfood': Icons.fastfood_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'local_bar': Icons.local_bar_rounded,
    'local_grocery_store': Icons.local_grocery_store_rounded,

    // Transporte
    'directions_car': Icons.directions_car_rounded,
    'local_gas_station': Icons.local_gas_station_rounded,
    'flight': Icons.flight_rounded,
    'two_wheeler': Icons.two_wheeler_rounded,
    'directions_bus': Icons.directions_bus_rounded,
    'train': Icons.train_rounded,

    // Hogar y servicios
    'home': Icons.home_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'receipt': Icons.receipt_rounded,
    'water_drop': Icons.water_drop_rounded,
    'wifi': Icons.wifi_rounded,
    'phone_iphone': Icons.phone_iphone_rounded,
    'phone': Icons.phone_rounded,
    'real_estate_agent': Icons.real_estate_agent_rounded,
    'lightbulb': Icons.lightbulb_rounded,

    // Ocio
    'sports_esports': Icons.sports_esports_rounded,
    'movie': Icons.movie_rounded,
    'music_note': Icons.music_note_rounded,
    'sports_soccer': Icons.sports_soccer_rounded,
    'beach_access': Icons.beach_access_rounded,
    'celebration': Icons.celebration_rounded,

    // Salud y bienestar
    'fitness_center': Icons.fitness_center_rounded,
    'medication': Icons.medication_rounded,
    'self_improvement': Icons.self_improvement_rounded,
    'spa': Icons.spa_rounded,
    'monitor_heart': Icons.monitor_heart_rounded,
    'local_hospital': Icons.local_hospital_rounded,
    'bedtime': Icons.bedtime_rounded,
    'directions_run': Icons.directions_run_rounded,
    'nightlight': Icons.nightlight_rounded,

    // Educación y trabajo
    'school': Icons.school_rounded,
    'menu_book': Icons.menu_book_rounded,
    'work': Icons.work_rounded,
    'laptop': Icons.laptop_rounded,
    'edit_note': Icons.edit_note_rounded,

    // Dinero
    'savings': Icons.savings_rounded,
    'payments': Icons.payments_rounded,
    'attach_money': Icons.attach_money_rounded,
    'credit_card': Icons.credit_card_rounded,
    'account_balance': Icons.account_balance_rounded,
    'account_balance_wallet': Icons.account_balance_wallet_rounded,
    'trending_up': Icons.trending_up_rounded,
    'trending_down': Icons.trending_down_rounded,
    'paid': Icons.paid_rounded,
    'wallet': Icons.wallet_rounded,

    // Personas
    'pets': Icons.pets_rounded,
    'child_care': Icons.child_care_rounded,
    'checkroom': Icons.checkroom_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'volunteer_activism': Icons.volunteer_activism_rounded,
    'family_restroom': Icons.family_restroom_rounded,
    'person': Icons.person_rounded,
    'group': Icons.group_rounded,

    // Otros
    'build': Icons.build_rounded,
    'flag': Icons.flag_rounded,
    'pie_chart': Icons.pie_chart_rounded,
    'analytics': Icons.analytics_rounded,
    'schedule': Icons.schedule_rounded,
    'event': Icons.event_rounded,
    'cake': Icons.cake_rounded,
    'place': Icons.place_rounded,
    'flight_takeoff': Icons.flight_takeoff_rounded,
    'directions_bike': Icons.directions_bike_rounded,
    'computer': Icons.computer_rounded,
    'headphones': Icons.headphones_rounded,
    'camera_alt': Icons.camera_alt_rounded,
  };

  static IconData resolve(String? name) {
    if (name == null || name.isEmpty) return fallback;
    return _map[name] ?? fallback;
  }

  /// Catálogo para el selector de iconos, con etiqueta en español.
  /// Refleja `ICONOS_CATEGORIA` del Dashboard original, ampliado.
  static const List<({String value, String label})> picker = [
    (value: 'sell', label: 'Etiqueta'),
    (value: 'shopping_cart', label: 'Carrito'),
    (value: 'restaurant', label: 'Restaurante'),
    (value: 'fastfood', label: 'Comida rápida'),
    (value: 'local_cafe', label: 'Café'),
    (value: 'directions_car', label: 'Carro'),
    (value: 'local_gas_station', label: 'Gasolina'),
    (value: 'two_wheeler', label: 'Moto'),
    (value: 'flight', label: 'Vuelo'),
    (value: 'home', label: 'Hogar'),
    (value: 'receipt_long', label: 'Factura'),
    (value: 'bolt', label: 'Electricidad'),
    (value: 'water_drop', label: 'Agua'),
    (value: 'wifi', label: 'Internet'),
    (value: 'phone_iphone', label: 'Celular'),
    (value: 'sports_esports', label: 'Videojuegos'),
    (value: 'movie', label: 'Cine'),
    (value: 'music_note', label: 'Música'),
    (value: 'fitness_center', label: 'Gimnasio'),
    (value: 'directions_run', label: 'Correr'),
    (value: 'self_improvement', label: 'Meditación'),
    (value: 'bedtime', label: 'Dormir'),
    (value: 'medication', label: 'Salud'),
    (value: 'menu_book', label: 'Leer'),
    (value: 'school', label: 'Educación'),
    (value: 'savings', label: 'Ahorro'),
    (value: 'pets', label: 'Mascotas'),
    (value: 'child_care', label: 'Niños'),
    (value: 'checkroom', label: 'Ropa'),
    (value: 'card_giftcard', label: 'Regalo'),
    (value: 'volunteer_activism', label: 'Donación'),
    (value: 'build', label: 'Reparación'),
    (value: 'payments', label: 'Pago'),
    (value: 'attach_money', label: 'Dinero'),
    (value: 'work', label: 'Trabajo'),
    (value: 'celebration', label: 'Celebración'),
    (value: 'flag', label: 'Meta'),
    (value: 'water_drop', label: 'Hidratación'),
  ];
}
