import 'package:flutter/material.dart';

class ToolItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<String> supportedFormats;
  final bool requiresNonConfidential;

  const ToolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.supportedFormats,
    this.requiresNonConfidential = false,
  });

  static const List<ToolItem> allTools = [
    ToolItem(
      id: 'merge_pdf',
      title: 'Merge PDF',
      description: 'Combine multiple PDFs into one document.',
      icon: Icons.call_merge_outlined,
      supportedFormats: ['PDF'],
    ),
    ToolItem(
      id: 'split_pdf',
      title: 'Split PDF',
      description: 'Separate one PDF into individual pages or ranges.',
      icon: Icons.call_split_outlined,
      supportedFormats: ['PDF'],
    ),
    ToolItem(
      id: 'compress_pdf',
      title: 'Compress PDF',
      description: 'Reduce PDF file size on-device.',
      icon: Icons.compress_outlined,
      supportedFormats: ['PDF'],
    ),
    ToolItem(
      id: 'image_convert',
      title: 'Image Convert',
      description: 'Convert between popular image formats.',
      icon: Icons.image_outlined,
      supportedFormats: ['JPG', 'PNG', 'HEIC', 'WEBP'],
    ),
    ToolItem(
      id: 'image_to_pdf',
      title: 'Image to PDF',
      description: 'Turn photos or scans into a clean PDF.',
      icon: Icons.photo_library_outlined,
      supportedFormats: ['PDF'],
    ),
    ToolItem(
      id: 'office_to_pdf',
      title: 'Office to PDF',
      description: 'Convert Word, Excel, and PowerPoint files.',
      icon: Icons.description_outlined,
      supportedFormats: ['Word', 'Excel', 'PowerPoint'],
      requiresNonConfidential: true,
    ),
  ];

  static ToolItem? findById(String id) {
    try {
      return allTools.firstWhere((tool) => tool.id == id);
    } catch (_) {
      return null;
    }
  }
}
