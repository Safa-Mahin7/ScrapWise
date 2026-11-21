import 'package:flutter/material.dart';

/// Standard scrap material identifiers accepted by ScrapWise backend.
enum ScrapMaterialCategory {
  paper,
  plastic,
  metal,
  glass,
  textile,
  other,
}

class ScrapMaterial {
  const ScrapMaterial({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    this.description,
  });

  final String id;
  final String name;
  final ScrapMaterialCategory category;
  final IconData icon;
  final String? description;

  static const List<ScrapMaterial> standardMaterials = [
    ScrapMaterial(
      id: 'newspaper',
      name: 'Newspaper',
      category: ScrapMaterialCategory.paper,
      icon: Icons.newspaper_rounded,
      description: 'Daily newspapers, gazettes',
    ),
    ScrapMaterial(
      id: 'old_books',
      name: 'Old Books & Notebooks',
      category: ScrapMaterialCategory.paper,
      icon: Icons.menu_book_rounded,
      description: 'Textbooks, notebooks, office paper',
    ),
    ScrapMaterial(
      id: 'cardboard',
      name: 'Cardboard & Cartons',
      category: ScrapMaterialCategory.paper,
      icon: Icons.inventory_2_outlined,
      description: 'Packaging boxes, corrugated sheets',
    ),
    ScrapMaterial(
      id: 'PET_plastic',
      name: 'PET Plastic Bottles',
      category: ScrapMaterialCategory.plastic,
      icon: Icons.local_drink_rounded,
      description: 'Clear water, juice, beverage containers',
    ),
    ScrapMaterial(
      id: 'mixed_plastic',
      name: 'Mixed / Hard Plastic',
      category: ScrapMaterialCategory.plastic,
      icon: Icons.recycling_rounded,
      description: 'Buckets, containers, plastic chairs',
    ),
    ScrapMaterial(
      id: 'iron',
      name: 'Iron & Cast Iron',
      category: ScrapMaterialCategory.metal,
      icon: Icons.hardware_rounded,
      description: 'Rods, pipes, window grills, structural scrap',
    ),
    ScrapMaterial(
      id: 'steel',
      name: 'Steel & Stainless Steel',
      category: ScrapMaterialCategory.metal,
      icon: Icons.shield_outlined,
      description: 'Utensils, stainless sheets, appliances',
    ),
    ScrapMaterial(
      id: 'aluminium',
      name: 'Aluminium',
      category: ScrapMaterialCategory.metal,
      icon: Icons.layers_outlined,
      description: 'Cans, window frames, cookware',
    ),
    ScrapMaterial(
      id: 'copper',
      name: 'Copper & Brass',
      category: ScrapMaterialCategory.metal,
      icon: Icons.electric_bolt_rounded,
      description: 'Wires (stripped), brass fittings, utensils',
    ),
    ScrapMaterial(
      id: 'glass',
      name: 'Glass Bottles',
      category: ScrapMaterialCategory.glass,
      icon: Icons.liquor_outlined,
      description: 'Unbroken glass jars, bottles',
    ),
    ScrapMaterial(
      id: 'clothes',
      name: 'Old Textiles / Clothes',
      category: ScrapMaterialCategory.textile,
      icon: Icons.checkroom_rounded,
      description: 'Worn out clothes, linen, fabrics',
    ),
    ScrapMaterial(
      id: 'other',
      name: 'Other Dry Scrap',
      category: ScrapMaterialCategory.other,
      icon: Icons.category_outlined,
      description: 'Miscellaneous non-hazardous scrap',
    ),
  ];
}
