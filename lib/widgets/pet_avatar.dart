import 'package:flutter/material.dart';
import '../services/local_pet_image_service.dart';
import '../theme/pawpulse_theme.dart';

/// A reusable avatar widget that displays a pet's profile picture.
///
/// It checks for a persistent local photo first, then falls back to any
/// bundled asset or network URL, and finally displays a default pet icon
/// if no image is available.
class PetAvatar extends StatelessWidget {
  final String? petId;
  final String? petImage;
  final double radius;
  final Color? backgroundColor;
  final Widget? fallbackChild;
  final VoidCallback? onTap;

  const PetAvatar({
    super.key,
    this.petId,
    this.petImage,
    this.radius = 20,
    this.backgroundColor,
    this.fallbackChild,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageProvider = LocalPetImageService().getPetImageProvider(
      petId: petId,
      fallbackUrl: petImage,
    );

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? PawPulseTheme.primaryCyan,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? (fallbackChild ??
                Icon(Icons.pets, size: radius * 1.1, color: Colors.white))
          : null,
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}
