import 'package:flutter/material.dart';

class Folder {
  final String id;
  final String name;
  final IconData icon;
  final bool isSecure;
  final int photoCount;
  final String? coverUrl;

  const Folder({
    required this.id,
    required this.name,
    this.icon = Icons.folder_outlined,
    this.isSecure = false,
    this.photoCount = 0,
    this.coverUrl,
  });

  Folder copyWith({
    String? id,
    String? name,
    IconData? icon,
    bool? isSecure,
    int? photoCount,
    String? coverUrl,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isSecure: isSecure ?? this.isSecure,
      photoCount: photoCount ?? this.photoCount,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }
}
